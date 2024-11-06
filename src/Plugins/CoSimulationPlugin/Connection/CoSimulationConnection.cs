//
// Copyright (c) 2010-2024 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Threading;
using System.Collections.Generic;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.CoSimulated;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;
using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection
{
    public static class CoSimulationConnectionExtensions {
        public static void ConnectToCoSimulation(this Emulation emulation,
                                                 string machineName,
                                                 string name = null,
                                                 long frequency = DefaultTimeunitFrequency,
                                                 string simulationFilePathLinux = null,
                                                 string simulationFilePathWindows = null,
                                                 string simulationFilePathMacOS = null,
                                                 string simulationContextLinux = null,
                                                 string simulationContextWindows = null,
                                                 string simulationContextMacOS = null,
                                                 ulong limitBuffer = DefaultLimitBuffer,
                                                 int timeout = DefaultTimeout,
                                                 string address = null
                                                 )
        {
            EmulationManager.Instance.CurrentEmulation.TryGetMachine(machineName, out var machine);
            if(machine == null)
            {
                throw new ConstructionException($"Machine {machineName} does not exist.");
            }

            var cosimConnection = new CoSimulationConnection(machine, name, frequency,
                    simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS,
                    simulationContextLinux, simulationContextWindows, simulationContextMacOS,
                    limitBuffer, timeout, address);
        }

        public const ulong DefaultLimitBuffer = 1000000;
        public const long DefaultTimeunitFrequency = 1000000000;
        public const int DefaultTimeout = 3000;
    }

    public partial class CoSimulationConnection : IHostMachineElement, IConnectable<ICoSimulationConnectible>, IHasOwnLife, IDisposable {
        public CoSimulationConnection(IMachine machine,
                string name,
                long frequency,
                string simulationFilePathLinux,
                string simulationFilePathWindows,
                string simulationFilePathMacOS,
                string simulationContextLinux,
                string simulationContextWindows,
                string simulationContextMacOS,
                ulong limitBuffer,
                int timeout,
                string address)
        {
            this.machine = machine;
            this.gpioEntries = new List<GPIOEntry>();

            RegisterInHostMachine(name);
            cosimConnection = SetupConnection(address, timeout, frequency, limitBuffer);
        }

        public void AttachTo(ICoSimulationConnectible peripheral)
        {
            peripheral.OnConnectionAttached(this);
        }

        public void DetachFrom(ICoSimulationConnectible peripheral)
        {
            peripheral.OnConnectionDetached(this);            
        }

        public void Dispose()
        {
            disposeInitiated = true;
            cosimConnection.Dispose();
        }

        public string SimulationContextLinux
        {
            get => SimulationContext;
            set
            {
#if PLATFORM_LINUX
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContextWindows
        {
            get => SimulationContext;
            set
            {
#if PLATFORM_WINDOWS
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContextMacOS
        {
            get => SimulationContext;
            set
            {
#if PLATFORM_OSX
                SimulationContext = value;
#endif
            }
        }

        public string SimulationContext
        {
            get => cosimConnection.Context;
            set
            {
                cosimConnection.Context = value;
            }
        }

        public string SimulationFilePathLinux
        {
            get => simulationFilePath;
            set
            {
#if PLATFORM_LINUX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathWindows
        {
            get => simulationFilePath;
            set
            {
#if PLATFORM_WINDOWS
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathMacOS
        {
            get => simulationFilePath;
            set
            {
#if PLATFORM_OSX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePath
        {
            get => simulationFilePath;
            set
            {
                if(String.IsNullOrWhiteSpace(value))
                {
                    return;
                }
                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    var message = $"Co-simulated peripheral already connected to \"{simulationFilePath}\", cannot change the file name!";
                    this.Log(LogLevel.Error, message);
                    throw new RecoverableException(message);
                }

                if(!String.IsNullOrWhiteSpace(value))
                {
                    cosimConnection.SimulationFilePath = value;
                    simulationFilePath = value;
                    Connect();
                }
            }
        }

        public void HandleMessage()
        {
            cosimConnection.HandleMessage();
        }

        public void Connect()
        {
            if(cosimConnection.IsConnected)
            {
                this.Log(LogLevel.Warning, "The co-simulated peripheral is already connected.");
                return;
            }
            cosimConnection.Connect();
        }

        public void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!cosimConnection.TrySendMessage(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Send error!");
            }
        }

        public void Respond(ActionType actionId, ulong offset, ulong value)
        {
            if(!cosimConnection.TryRespond(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Respond error!");
            }
        }

        public bool IsConnected => cosimConnection.IsConnected;

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
            cosimConnection.Start();
        }

        public void Pause()
        {
            cosimConnection.Pause();
        }

        public bool IsPaused => cosimConnection.IsPaused;

        public void Resume()
        {
            cosimConnection.Resume();
        }

        public void Reset()
        {
            // We currently have no way to tell the simulation that a particular peripheral is resetting.
            // Reset is treated as a global event.
            if(timer != null)
            {
                timer.Reset();
            }
            Send(ActionType.ResetPeripheral, 0, 0);
        }

        public void SendGPIO(int number, bool value)
        {
            Write(ActionType.Interrupt, number, value ? 1ul : 0ul);
        }

        public string ConnectionParameters => (cosimConnection as SocketConnection)?.ConnectionParameters ?? "";

        public delegate bool OnReceiveDelegate(ProtocolMessage message);
        public OnReceiveDelegate OnReceive { get; set; }

        public void RegisterOnGPIOReceive(Action<int, bool> callback, Range translationRange)
        {
            foreach(GPIOEntry entry in gpioEntries)
            {
                if(entry.range.Intersects(translationRange))
                {
                    throw new ConfigurationException($"Cannot register cosimulation GPIO receive callback on range [{translationRange.StartAddress}, {translationRange.EndAddress}] - there already is a callback registered on intersecting range [{entry.range.StartAddress}, {entry.range.EndAddress}]"); 
                }
            }
            gpioEntries.Add(new GPIOEntry(translationRange, callback));
        }

        public void UnregisterOnGPIOReceive(Range translationRange)
        {
            gpioEntries.RemoveAll(entry => entry.range.Equals(translationRange));
        }

        public void Write(ActionType type, long offset, ulong value)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot write to peripheral. Set SimulationFilePath or connect to a simulator first!");
                return;
            }
            Send(type, (ulong)offset, value);
            ValidateResponse(Receive());
        }

        public ulong Read(ActionType type, long offset)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot read from peripheral. Set SimulationFilePath or connect to a simulator first!");
                return 0;
            }
            Send(type, (ulong)offset, 0);
            var result = Receive();
            ValidateResponse(result);

            return result.Data;
        }

        private void AbortAndLogError(string message)
        {
            // It's safe to call AbortAndLogError from any thread.
            // Calling it from many threads may cause throwing more than one exception.
            if(disposeInitiated)
            {
                return;
            }
            this.Log(LogLevel.Error, message);
            cosimConnection.Abort();

            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private ICoSimulationConnection SetupConnection(string address, int timeout, long frequency, ulong limitBuffer)
        {
            started = false;
            ICoSimulationConnection cosimConnection = null;
            if(address != null)
            {
                cosimConnection = new SocketConnection(this, timeout, HandleReceivedMessage, address);
            }
            else
            {
                cosimConnection = new LibraryConnection(this, timeout, HandleReceivedMessage);
            }

            // Setup time synchronization
            // Frequency 0 means we never sync the time
            if(frequency != 0)
            {
                allTicksProcessedARE = new AutoResetEvent(initialState: false);
                timer = new LimitTimer(machine.ClockSource, frequency, null, LimitTimerName, limitBuffer, enabled: true, eventEnabled: true, autoUpdate: true);
                timer.LimitReached += () =>
                {
                    if(!cosimConnection.TrySendMessage(new ProtocolMessage(ActionType.TickClock, 0, limitBuffer)))
                    {
                        AbortAndLogError("Send error!");
                    }
                    this.NoisyLog("Tick: TickClock sent, waiting for the verilated peripheral...");
                    if(!allTicksProcessedARE.WaitOne(timeout))
                    {
                        AbortAndLogError("Timeout reached while waiting for a tick response.");
                    }
                    this.NoisyLog("Tick: Co-simulation peripheral finished evaluating the model.");
                };
            }

            return cosimConnection;
        }

        private void ValidateResponse(ProtocolMessage message)
        {
            if(message.ActionId == ActionType.Error)
            {
                this.Log(LogLevel.Warning, "Operation error reported by the co-simulation!");
            }
        }

        private ProtocolMessage Receive()
        {
            if(!cosimConnection.TryReceiveMessage(out var message))
            {
                AbortAndLogError("Receive error!");
            }

            return message;
        }

        private void HandleReceivedMessage(ProtocolMessage message)
        {
            if(OnReceive != null)
            {
                foreach(OnReceiveDelegate or in OnReceive.GetInvocationList())
                {
                    if(or(message))
                    {
                        return;
                    }
                }
            }

            switch(message.ActionId)
            {
                case ActionType.InvalidAction:
                    this.Log(LogLevel.Warning, "Invalid action received");
                    break;
                case ActionType.Interrupt:
                    HandleGPIO(message);
                    break;
                case ActionType.PushByte:
                    this.Log(LogLevel.Noisy, "Writing byte: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteByte(message.Address, (byte)message.Data);
                    Respond(ActionType.PushConfirmation, 0, 0);
                    break;
                case ActionType.PushWord:
                    this.Log(LogLevel.Noisy, "Writing word: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteWord(message.Address, (ushort)message.Data);
                    Respond(ActionType.PushConfirmation, 0, 0);
                    break;
                case ActionType.PushDoubleWord:
                    this.Log(LogLevel.Noisy, "Writing double word: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteDoubleWord(message.Address, (uint)message.Data);
                    Respond(ActionType.PushConfirmation, 0, 0);
                    break;
                case ActionType.PushQuadWord:
                    this.Log(LogLevel.Noisy, "Writing quad word: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteQuadWord(message.Address, message.Data);
                    Respond(ActionType.PushConfirmation, 0, 0);
                    break;
                case ActionType.GetByte:
                    this.Log(LogLevel.Noisy, "Requested byte from address: 0x{0:X}", message.Address);
                    Respond(ActionType.WriteToBus, 0, machine.SystemBus.ReadByte(message.Address));
                    break;
                case ActionType.GetWord:
                    this.Log(LogLevel.Noisy, "Requested word from address: 0x{0:X}", message.Address);
                    Respond(ActionType.WriteToBus, 0, machine.SystemBus.ReadWord(message.Address));
                    break;
                case ActionType.GetDoubleWord:
                    this.Log(LogLevel.Noisy, "Requested double word from address: 0x{0:X}", message.Address);
                    Respond(ActionType.WriteToBus, 0, machine.SystemBus.ReadDoubleWord(message.Address));
                    break;
                case ActionType.GetQuadWord:
                    this.Log(LogLevel.Noisy, "Requested quad word from address: 0x{0:X}", message.Address);
                    Respond(ActionType.WriteToBus, 0, machine.SystemBus.ReadQuadWord(message.Address));
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

        private void HandleGPIO(ProtocolMessage message)
        {
            var gpioNumber = message.Address;
            bool newValue = message.Data != 0;
            foreach(GPIOEntry entry in gpioEntries)
            {
                if(entry.range.Contains(gpioNumber))
                {
                    // NOTE: Callback is responsible for translating into local interrupt offsets using
                    // the range it registered with - local GPIO number is (gpioNumber - range.StartAddress).
                    entry.callback((int)gpioNumber, newValue);
                    return;
                }
            }
        }

        private void RegisterInHostMachine(string name)
        {
            if(name == null)
            {
                name = "cosimulation_connection";
            }

            var hostMachineElementNames = EmulationManager.Instance.CurrentEmulation.HostMachine.GetNames();

            // Assure the name is unique inside of the HostMachine by appending a number at the end.
            if(hostMachineElementNames.Contains(name))
            {
                var uniqueNo = 0;
                while(hostMachineElementNames.Contains($"{name}{uniqueNo}"))
                {
                    uniqueNo += 1;
                }
                name = $"{name}{uniqueNo}";
            }
            EmulationManager.Instance.CurrentEmulation.HostMachine.AddHostMachineElement(this, name);
        }

        private struct GPIOEntry
        {
            public GPIOEntry(Range range, Action<int, bool> callback)
            {
                this.range = range;
                this.callback = callback;
            }

            public readonly Range range;
            public readonly Action<int, bool> callback;
        };


        private readonly ICoSimulationConnection cosimConnection;

        private const int DefaultTimeout = 3000;
        private string simulationFilePath;
        private IMachine machine;
        private bool started;
        private volatile bool disposeInitiated;
        private const string LimitTimerName = "CoSimulationClock";
        private LimitTimer timer;
        private AutoResetEvent allTicksProcessedARE;
        private List<GPIOEntry> gpioEntries;
    }
}
