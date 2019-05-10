//
// Copyright (c) 2010-2019 Antmicro
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
using Mono.Unix.Native;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class BaseDoubleWordVerilatedPeripheral : IDoubleWordPeripheral, IDisposable
    {
        public BaseDoubleWordVerilatedPeripheral(Machine machine, string simulationFilePath, long frequency, ulong limitBuffer = LimitBuffer, double timeout = DefaultTimeout)
        {
            mainSocket = new CommunicationChannel(timeout);
            asyncEventsSocket = new CommunicationChannel(timeout);
            receiveThread = new Thread(ReceiveLoop)
            {
                IsBackground = true,
                Name = "Verilated.Receiver"
            };
            SimulationFilePath = simulationFilePath;
            InitTimer(machine.ClockSource, frequency, limitBuffer);

        }

        public uint ReadDoubleWord(long offset)
        {
            if(!isConnectionValid)
            {
                AbortAndLogError("Connection error!");
            }
            Send(ActionType.ReadFromBus, (ulong)offset, 0);
            var result = Receive();
            CheckValidation(result);

            return (uint)result.Data;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            if(!isConnectionValid)
            {
                AbortAndLogError("Connection error!");
            }
            Send(ActionType.WriteToBus, (ulong)offset, value);
            CheckValidation(Receive());
        }

        public void ReceiveLoop()
        {
            isConnected = true;

            while(isConnected)
            {
                if(asyncEventsSocket.TryReceive(out var message))
                {
                    HandleReceived(message);
                }
            }
        }

        public void Reset()
        {
            Send(ActionType.ResetPeripheral, 0, 0);
        }

        public void Dispose()
        {
            if(isConnected)
            {
                mainSocket.TrySend(new ProtocolMessage(ActionType.Disconnect, 0, 0));
            }
            isConnected = false;
            if(receiveThread.IsAlive)
            {
                receiveThread.Join();
            }
            if(verilatedProcess != null)
            {
                verilatedProcess.Close();
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
                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    throw new RecoverableException("Verilated peripheral already initialized, cannot change the file name");
                }
                simulationFilePath = value;
                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    this.Log(LogLevel.Debug, "Trying to run and connect to '{0}'", simulationFilePath);
#if !PLATFORM_WINDOWS
                    Mono.Unix.Native.Syscall.chmod(simulationFilePath, FilePermissions.S_IRWXU); //setting permissions to 0x700
#endif
                    InitVerilatedProcess(simulationFilePath, mainSocket.Port, asyncEventsSocket.Port);
                    receiveThread.Start();
                    Handshake();
                }
            }
        }

        protected void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!mainSocket.TrySend(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Connection timeout!");
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
                    this.Log((LogLevel)(int)message.Data, "Verilated: ", asyncEventsSocket.ReceiveString());
                    break;
                case ActionType.Interrupt:
                    HandleInterrupt(message);
                    break;
            }
        }

        protected virtual void HandleInterrupt(ProtocolMessage interrupt)
        {
            this.Log(LogLevel.Info, "Unhandled interrupt: ", interrupt.Address);
        }

        protected void CheckValidation(ProtocolMessage message)
        {
            if(message.ActionId == ActionType.Error)
            {
                AbortAndLogError("Operation error!");
            }
        }

        protected const ulong LimitBuffer = 1000000;
        protected const int DefaultTimeout = 3;

        private void InitTimer(IClockSource clockSource, long frequency, ulong limit)
        {
            var timer = new LimitTimer(clockSource, frequency, this, LimitTimerName, limit, enabled: true, eventEnabled: true, autoUpdate: true);
            timer.LimitReached += () =>
            {
                Send(ActionType.TickClock, 0, limit);
            };
        }

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

                verilatedProcess.Exited += (sender, args) =>
                {
                    this.Log(LogLevel.Debug, "Disconnecting from '{0}'", simulationFilePath);
                    isConnectionValid = false;
                };

                verilatedProcess.Start();
            }
            catch(Exception ex)
            {
                throw new ConstructionException(ex.Message);
            }
        }

        private void Handshake()
        {
            mainSocket.TrySend(new ProtocolMessage(ActionType.Handshake, 0, 0));
            if(!mainSocket.TryReceive(out var result))
            {
                this.Log(LogLevel.Warning, "Failed to connect to the verilated peripheral");
                isConnectionValid = false;
                return;
            }
            isConnectionValid = result.ActionId == ActionType.Handshake;
            this.Log(LogLevel.Debug, "Connected to the verilated peripheral. Connection is {0}valid.", isConnectionValid ? String.Empty : "not ");
        }

        private ProtocolMessage Receive()
        {
            if(!mainSocket.TryReceive(out var message))
            {
                AbortAndLogError("Connection timeout!");
            }

            return message;
        }

        private void AbortAndLogError(string message)
        {
            isConnected = false;
            this.Log(LogLevel.Error, message);
            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private readonly CommunicationChannel mainSocket;
        private bool isConnectionValid;
        private readonly CommunicationChannel asyncEventsSocket;
        private readonly Thread receiveThread;
        private Process verilatedProcess;
        private bool isConnected;
        private string simulationFilePath;

        private const string LimitTimerName = "VerilatorIntegrationClock";
    }
}
