//
// Copyright (c) 2010-2024 Antmicro
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
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class BaseCoSimulatedPeripheral : IPeripheral, IDisposable, IHasOwnLife
    {
        public BaseCoSimulatedPeripheral(string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null,
            int timeout = DefaultTimeout, string address = null)
        {
            started = false;
            if(address != null)
            {
                cosimulationConnection = new SocketConnection(this, timeout, HandleReceivedMessage, address);
            }
            else
            {
                cosimulationConnection = new LibraryConnection(this, timeout, HandleReceivedMessage);
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
            if(cosimulationConnection.IsConnected)
            {
                this.Log(LogLevel.Warning, "The Verilated peripheral is already connected.");
                return;
            }
            cosimulationConnection.Connect();
        }

        public void Dispose()
        {
            disposeInitiated = true;
            cosimulationConnection.Dispose();
        }

        public void Pause()
        {
            cosimulationConnection.Pause();
        }

        public void Resume()
        {
            cosimulationConnection.Resume();
        }

        public bool IsPaused => cosimulationConnection.IsPaused;

        public bool IsConnected => cosimulationConnection.IsConnected;

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
                return cosimulationConnection.Context;
            }
            set
            {
                cosimulationConnection.Context = value;
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
                    cosimulationConnection.SimulationFilePath = value;
                    simulationFilePath = value;
                    Connect();
                }
            }
        }

        public string ConnectionParameters => (cosimulationConnection as SocketConnection)?.ConnectionParameters ?? "";

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
            cosimulationConnection.Start();
        }

        public void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!cosimulationConnection.TrySendMessage(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Send error!");
            }
        }

        public void Respond(ActionType actionId, ulong offset, ulong value)
        {
            if(!cosimulationConnection.TryRespond(new ProtocolMessage(actionId, offset, value)))
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
            cosimulationConnection.HandleMessage();
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
            if(!cosimulationConnection.TryReceiveMessage(out var message))
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
            cosimulationConnection.Abort();

            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        protected string simulationFilePath;
        protected ICoSimulationConnection cosimulationConnection;

        private void LogAndThrowRE(string info)
        {
            this.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private bool started;
        private volatile bool disposeInitiated;
    }
}
