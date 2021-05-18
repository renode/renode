//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Diagnostics;
using System.Threading;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using Antmicro.Renode.Time;
#if !PLATFORM_WINDOWS
using Mono.Unix.Native;
#endif

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class BaseDoubleWordVerilatedPeripheral : IDoubleWordPeripheral, IDisposable, IHasOwnLife
    {
        public BaseDoubleWordVerilatedPeripheral(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout)
        {
            this.machine = machine;
            this.msTimeout = timeout;
            pauseMRES = new ManualResetEventSlim(initialState: true);
            allTicksProcessedARE = new AutoResetEvent(initialState: false);
            mainSocket = new CommunicationChannel(this, msTimeout);
            asyncEventsSocket = new CommunicationChannel(this, Timeout.Infinite);
            receiveThread = new Thread(ReceiveLoop)
            {
                IsBackground = true,
                Name = "Verilated.Receiver"
            };
            timer = new LimitTimer(machine.ClockSource, frequency, this, LimitTimerName, limitBuffer, enabled: false, eventEnabled: true, autoUpdate: true);
            timer.LimitReached += () =>
            {
                Send(ActionType.TickClock, 0, limitBuffer);
                this.NoisyLog("Tick: TickClock sent, waiting for the verilated peripheral...");
                allTicksProcessedARE.WaitOne();
                this.NoisyLog("Tick: Verilated peripheral finished evaluating the model.");
            };
            SimulationFilePathLinux = simulationFilePathLinux;
            SimulationFilePathWindows = simulationFilePathWindows;
            SimulationFilePathMacOS = simulationFilePathMacOS;
        }

        public uint ReadDoubleWord(long offset)
        {
            Send(ActionType.ReadFromBus, (ulong)offset, 0);
            var result = Receive();
            CheckValidation(result);

            return (uint)result.Data;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            Send(ActionType.WriteToBus, (ulong)offset, value);
            CheckValidation(Receive());
        }

        public void ReceiveLoop()
        {
            while(!disposeInitiated && asyncEventsSocket.Connected)
            {
                if(asyncEventsSocket.ReceiveMessage(out var message))
                {
                    pauseMRES.Wait();
                    if(!disposeInitiated)
                    {
                        HandleReceived(message);
                    }
                }
                else
                {
                    AbortAndLogError("Connection error!");
                }

                // Pause in ReceiveLoop() has to be handled manually
                pauseMRES.Wait();
            }
        }

        public void Reset()
        {
            Send(ActionType.ResetPeripheral, 0, 0);
            timer.Reset();
        }

        public void Dispose()
        {
            disposeInitiated = true;
            asyncEventsSocket.CancelCommunication();

            if(receiveThread.IsAlive)
            {
                if(!receiveThread.Join(500))
                {
                    this.NoisyLog("ReceiveLoop didn't join, will be aborted...");
                    receiveThread.Abort();
                }
            }
            pauseMRES.Dispose();

            if(verilatedProcess != null)
            {
                // Ask verilatedProcess to close, kill if it doesn't
                if(!verilatedProcess.HasExited)
                {
                    this.DebugLog($"Verilated peripheral '{simulationFilePath}' is still working...");
                    var exited = false;

                    if(mainSocket.Connected)
                    {
                        this.DebugLog("Trying to close it gracefully by sending 'Disconnect' message...");
                        mainSocket.SendMessage(new ProtocolMessage(ActionType.Disconnect, 0, 0));
                        mainSocket.CancelCommunication();
                        exited = verilatedProcess.WaitForExit(500);
                    }

                    if(exited)
                    {
                        this.DebugLog("Verilated peripheral exited gracefully.");
                    }
                    else
                    {
                        KillVerilatedProcess();
                        this.Log(LogLevel.Warning, "Verilated peripheral had to be killed.");
                    }
                }
                verilatedProcess.Dispose();
            }

            mainSocket.Dispose();
            asyncEventsSocket.Dispose();
        }

        public void Pause()
        {
            pauseMRES.Reset();
        }

        public void Resume()
        {
            pauseMRES.Set();
        }

        public string SimulationFilePathLinux
        {
            get
            {
                return simulationFilePath;
            }
            set
            {
#if PLATFORM_LINUX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathWindows
        {
            get
            {
                return simulationFilePath;
            }
            set
            {
#if PLATFORM_WINDOWS
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathMacOS
        {
            get
            {
                return simulationFilePath;
            }
            set
            {
#if PLATFORM_OSX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePath
        {
            get
            {
                return simulationFilePath;
            }
            set
            {
                if(String.IsNullOrWhiteSpace(value))
                {
                    return;
                }
                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    LogAndThrowRE("Verilated peripheral already connected, cannot change the file name!");
                }

                if(!String.IsNullOrWhiteSpace(value))
                {
                    this.Log(LogLevel.Debug,
                        "Trying to run and connect to the verilated peripheral '{0}' through ports {1} and {2}...",
                        value, mainSocket.ListenerPort, asyncEventsSocket.ListenerPort);
#if !PLATFORM_WINDOWS
                    Mono.Unix.Native.Syscall.chmod(value, FilePermissions.S_IRWXU); //setting permissions to 0x700
#endif
                    InitVerilatedProcess(value, mainSocket.ListenerPort, asyncEventsSocket.ListenerPort);

                    if(!mainSocket.AcceptConnection(msTimeout)
                        || !asyncEventsSocket.AcceptConnection(msTimeout)
                        || !TryHandshake())
                    {
                        mainSocket.ResetConnections();
                        asyncEventsSocket.ResetConnections();
                        KillVerilatedProcess();

                        LogAndThrowRE($"Connection to the verilated peripheral ({value}) failed!");
                    }
                    else
                    {
                        // If connected succesfully, listening sockets can be closed
                        mainSocket.CloseListener();
                        asyncEventsSocket.CloseListener();

                        timer.Enabled = true;

                        this.Log(LogLevel.Debug, "Connected to the verilated peripheral!");
                        simulationFilePath = value;
                    }
                }
            }
        }

        public void Start()
        {
            if(simulationFilePath == null)
            {
                throw new RecoverableException("Cannot start emulation. Set SimulationFilePath first!");
            }
            else
            {
                receiveThread.Start();
            }
        }

        protected void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!mainSocket.SendMessage(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Send error!");
            }
        }

        protected virtual void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.InvalidAction:
                    this.Log(LogLevel.Warning, "Invalid action received");
                    break;
                case ActionType.LogMessage:
                    // message.Address is used to transfer log length
                    if(asyncEventsSocket.ReceiveString(out var log, (int)message.Address))
                    {
                        this.Log((LogLevel)(int)message.Data, $"Verilated peripheral: {log}");
                    }
                    else
                    {
                        this.Log(LogLevel.Warning, "Failed to receive log message!");
                    }
                    break;
                case ActionType.Interrupt:
                    HandleInterrupt(message);
                    break;
                case ActionType.PushData:
                    this.Log(LogLevel.Noisy, "Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteDoubleWord(message.Address, (uint)message.Data);
                    break;
                case ActionType.GetData:
                    this.Log(LogLevel.Noisy, "Requested data from address: 0x{0:X}", message.Address);
                    var data = machine.SystemBus.ReadDoubleWord(message.Address);
                    Send(ActionType.WriteToBus, 0, data);
                    break;
                case ActionType.TickClock:
                    allTicksProcessedARE.Set();
                    break;
                default:
                    this.Log(LogLevel.Warning, "Unhandled message: ActionId = {0}; Address: 0x{1:X}; Data: 0x{2:X}!",
                        message.ActionId, message.Address, message.Data);
                    break;
            }
        }

        protected virtual void HandleInterrupt(ProtocolMessage interrupt)
        {
            this.Log(LogLevel.Info, "Unhandled interrupt: '{0}'", interrupt.Address);
        }

        protected void CheckValidation(ProtocolMessage message)
        {
            if(message.ActionId == ActionType.Error)
            {
                AbortAndLogError("Operation error!");
            }
        }

        protected const ulong LimitBuffer = 1000000;
        protected const int DefaultTimeout = 3000;

        private void InitVerilatedProcess(string filePath, int mainPort, int receiverPort)
        {
            try
            {
                verilatedProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(filePath)
                    {
                        UseShellExecute = false,
                        Arguments = $"{mainPort} {receiverPort}"
                    }
                };

                verilatedProcess.Start();
            }
            catch(Exception)
            {
                verilatedProcess = null;
                LogAndThrowRE($"Error starting verilated peripheral!");
            }
        }

        private ProtocolMessage Receive()
        {
            if(!mainSocket.ReceiveMessage(out var message))
            {
                AbortAndLogError("Receive error!");
            }

            return message;
        }

        private void AbortAndLogError(string message)
        {
            if(disposeInitiated)
            {
                return;
            }
            this.Log(LogLevel.Error, message);

            receiveThread.Abort();
            KillVerilatedProcess();
            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private void KillVerilatedProcess()
        {
            try
            {
                verilatedProcess?.Kill();
            }
            catch
            {
                return;
            }
        }

        private void LogAndThrowRE(string info)
        {
            this.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private bool TryHandshake()
        {
            return mainSocket.SendMessage(new ProtocolMessage(ActionType.Handshake, 0, 0))
                   && mainSocket.ReceiveMessage(out var result)
                   && result.ActionId == ActionType.Handshake;
        }

        private bool disposeInitiated;
        private Process verilatedProcess;
        private string simulationFilePath;
        private readonly AutoResetEvent allTicksProcessedARE;
        private readonly LimitTimer timer;
        private readonly CommunicationChannel mainSocket;
        private readonly CommunicationChannel asyncEventsSocket;
        private readonly Thread receiveThread;
        private readonly Machine machine;
        private readonly ManualResetEventSlim pauseMRES;
        private readonly int msTimeout;

        private const string LimitTimerName = "VerilatorIntegrationClock";
    }
}
