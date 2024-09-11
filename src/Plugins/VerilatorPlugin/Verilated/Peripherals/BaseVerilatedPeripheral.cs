//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading;
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
    public class BaseVerilatedPeripheral : IPeripheral, IDisposable, IHasOwnLife
    {
        public BaseVerilatedPeripheral(string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null,
            int timeout = DefaultTimeout, string address = null)
        {
            started = false;
            if(address != null)
            {
                verilatorConnection = new SocketVerilatorConnection(this, timeout, HandleReceivedMessage, address);
            }
            else
            {
                verilatorConnection = new LibraryVerilatorConnection(this, timeout, HandleReceivedMessage);
            }

            SimulationFilePathLinux = simulationFilePathLinux;
            SimulationFilePathWindows = simulationFilePathWindows;
            SimulationFilePathMacOS = simulationFilePathMacOS;

            SimulationContextLinux = simulationContextLinux;
            SimulationContextWindows = simulationContextWindows;
            SimulationContextMacOS = simulationContextMacOS;
        }

        public Action<ProtocolMessage> OnReceive { get; set; }

        public virtual void Reset()
        {
            Send(ActionType.ResetPeripheral, 0, 0);
        }

        public void Connect()
        {
            if(verilatorConnection.IsConnected)
            {
                this.Log(LogLevel.Warning, "The Verilated peripheral is already connected.");
                return;
            }
            verilatorConnection.Connect();
        }

        public void Dispose()
        {
            disposeInitiated = true;
            verilatorConnection.Dispose();
        }

        public void Pause()
        {
            verilatorConnection.Pause();
        }

        public void Resume()
        {
            verilatorConnection.Resume();
        }

        public bool IsPaused => verilatorConnection.IsPaused;

        public bool IsConnected => verilatorConnection.IsConnected;

        public string SimulationContextLinux
        {
            get
            {
                return SimulationContext;
            }
            set
            {
#if PLATFORM_LINUX
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContextWindows
        {
            get
            {
                return SimulationContext;
            }
            set
            {
#if PLATFORM_WINDOWS
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContextMacOS
        {
            get
            {
                return SimulationContext;
            }
            set
            {
#if PLATFORM_OSX
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContext
        {
            get
            {
                return verilatorConnection.Context;
            }
            set
            {
                verilatorConnection.Context = value;
            }
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
                    verilatorConnection.SimulationFilePath = value;
                    simulationFilePath = value;
                    Connect();
                }
            }
        }

        public string ConnectionParameters => (verilatorConnection as SocketVerilatorConnection)?.ConnectionParameters ?? "";

        public void Start()
        {
            if(started)
            {
                return;
            }
            started = true;
            if(!IsConnected)
            {
                throw new RecoverableException("Cannot start emulation. Set SimulationFilePath or connect to a simulator first!");
            }
            verilatorConnection.Start();
        }

        public void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!verilatorConnection.TrySendMessage(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Send error!");
            }
        }

        public void Respond(ActionType actionId, ulong offset, ulong value)
        {
            if(!verilatorConnection.TryRespond(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Respond error!");
            }
        }

        public virtual void HandleReceivedMessage(ProtocolMessage message)
        {
            var or = OnReceive;
            if(or != null)
            {
                or(message);
            }
            else
            {
                this.Log(LogLevel.Warning, "Unhandled message: ActionId = {0}; Address: 0x{1:X}; Data: 0x{2:X}!",
                    message.ActionId, message.Address, message.Data);
            }
        }

        public void HandleMessage()
        {
            verilatorConnection.HandleMessage();
        }

        public const int DefaultTimeout = 3000;

        protected virtual void HandleInterrupt(ProtocolMessage interrupt)
        {
            this.Log(LogLevel.Info, "Unhandled interrupt: '{0}'", interrupt.Address);
        }

        protected void CheckValidation(ProtocolMessage message)
        {
            if(message.ActionId == ActionType.Error)
            {
                this.Log(LogLevel.Warning, "Operation error reported by the co-simulation!");
            }
        }

        protected ProtocolMessage Receive()
        {
            if(!verilatorConnection.TryReceiveMessage(out var message))
            {
                AbortAndLogError("Receive error!");
            }

            return message;
        }

        protected void AbortAndLogError(string message)
        {
            // It's safe to call AbortAndLogError from any thread.
            // Calling it from many threads may cause throwing more than one exception.
            if(disposeInitiated)
            {
                return;
            }
            this.Log(LogLevel.Error, message);
            verilatorConnection.Abort();

            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        protected string simulationFilePath;
        protected IVerilatorConnection verilatorConnection;

        private void LogAndThrowRE(string info)
        {
            this.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private bool started;
        private volatile bool disposeInitiated;
    }
}
