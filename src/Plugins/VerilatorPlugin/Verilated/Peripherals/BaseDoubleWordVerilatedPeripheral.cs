//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class BaseDoubleWordVerilatedPeripheral : IDoubleWordPeripheral, IDisposable, IHasOwnLife, INumberedGPIOOutput
    {
        public BaseDoubleWordVerilatedPeripheral(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfInterrupts = 0)
        {
            this.machine = machine;
            allTicksProcessedARE = new AutoResetEvent(initialState: false);
            if(address != null)
            {
                verilatedPeripheral = new SocketBasedVerilatedPeripheral(this, timeout, HandleReceived, address);
            }
            else
            {
                verilatedPeripheral = new DLLBasedVerilatedPeripheral(this, timeout, HandleReceived);
            }

            timer = new LimitTimer(machine.ClockSource, frequency, this, LimitTimerName, limitBuffer, enabled: false, eventEnabled: true, autoUpdate: true);
            timer.LimitReached += () =>
            {
                if(!verilatedPeripheral.TrySendMessage(new ProtocolMessage(ActionType.TickClock, 0, limitBuffer)))
                {
                    AbortAndLogError("Send error!");
                }
                this.NoisyLog("Tick: TickClock sent, waiting for the verilated peripheral...");
                allTicksProcessedARE.WaitOne();
                this.NoisyLog("Tick: Verilated peripheral finished evaluating the model.");
            };

            SimulationFilePathLinux = simulationFilePathLinux;
            SimulationFilePathWindows = simulationFilePathWindows;
            SimulationFilePathMacOS = simulationFilePathMacOS;

            var innerConnections = new Dictionary<int, IGPIO>();
            for(int i = 0; i < numberOfInterrupts; i++)
            {
                innerConnections[i] = new GPIO();
            }

            Connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);
        }

        public uint ReadDoubleWord(long offset)
        {
            if(String.IsNullOrWhiteSpace(simulationFilePath))
            {
                this.Log(LogLevel.Warning, "Cannot read from peripheral. Set SimulationFilePath first!");
                return 0;
            }
            Send(ActionType.ReadFromBus, (ulong)offset, 0);
            var result = Receive();
            CheckValidation(result);

            return (uint)result.Data;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            if(String.IsNullOrWhiteSpace(simulationFilePath))
            {
                this.Log(LogLevel.Warning, "Cannot write to peripheral. Set SimulationFilePath first!");
                return;
            }
            Send(ActionType.WriteToBus, (ulong)offset, value);
            CheckValidation(Receive());
        }

        public void Reset()
        {
            Send(ActionType.ResetPeripheral, 0, 0);
            timer.Reset();
        }

        public void Dispose()
        {
            disposeInitiated = true;
            verilatedPeripheral.Dispose();
        }

        public void Pause()
        {
            verilatedPeripheral.Pause();
        }

        public void Resume()
        {
            verilatedPeripheral.Resume();
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
                    this.Log(LogLevel.Warning, "SimulationFilePath not set!");
                    return;
                }
                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    LogAndThrowRE("Verilated peripheral already connected, cannot change the file name!");
                }

                if(!String.IsNullOrWhiteSpace(value))
                {
                    verilatedPeripheral.SimulationFilePath = value;
                    simulationFilePath = value;
                    timer.Enabled = true;
                }
            }
        }

        public void Start()
        {
            if(String.IsNullOrWhiteSpace(simulationFilePath))
            {
                throw new RecoverableException("Cannot start emulation. Set SimulationFilePath first!");
            }
            verilatedPeripheral.Start();
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        protected void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!verilatedPeripheral.TrySendMessage(new ProtocolMessage(actionId, offset, value)))
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
            if (!Connections.TryGetValue((int)interrupt.Address, out var connection))
            {
                this.Log(LogLevel.Warning, "Unhandled interrupt: '{0}'", interrupt.Address);
                return;
            }

            connection.Set(interrupt.Data != 0);
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

        private ProtocolMessage Receive()
        {
            if(!verilatedPeripheral.TryReceiveMessage(out var message))
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
            verilatedPeripheral.Abort();
            
            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private void LogAndThrowRE(string info)
        {
            this.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private bool disposeInitiated;
        private string simulationFilePath;
        private IVerilatedPeripheral verilatedPeripheral;
        private readonly AutoResetEvent allTicksProcessedARE;
        private readonly Machine machine;
        private readonly LimitTimer timer;

        private const string LimitTimerName = "VerilatorIntegrationClock";
    }
}
