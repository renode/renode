//
// Copyright (c) 2010-2024 Antmicro
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
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;
using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class CoSimulatedPeripheral : ICoSimulationConnectible, IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, IBusPeripheral, IDisposable, INumberedGPIOOutput, IGPIOReceiver, IAbsoluteAddressAware
    {
        public CoSimulatedPeripheral(Machine machine, int maxWidth = 64, bool useAbsoluteAddress = false, long frequency = VerilogTimeunitFrequency, 
            string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfOutputGPIOs = 0, bool createConnection = true,
            int outputGPIOOffset = -1, int inputGPIOOffset = 0)
        {
            UseAbsoluteAddress = useAbsoluteAddress;
            this.maxWidth = maxWidth;
            this.inputGPIOOffset = inputGPIOOffset;

            if(createConnection)
            {
                outputGPIORange = new Range(0, (ulong)numberOfOutputGPIOs);
                connection = new CoSimulationConnection(machine, "cosimulation_connection", frequency,
                        simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS,
                        simulationContextLinux, simulationContextWindows, simulationContextMacOS,
                        limitBuffer, timeout, address);
                connection.AttachTo(this);
            } else {
                if(numberOfOutputGPIOs != 0 && outputGPIOOffset < 0)
                {
                    throw new ConstructionException(
                            $"CoSimulationPeripheral uses interrupts and an external connection, but has no {nameof(outputGPIOOffset)} defined");
                }
                outputGPIORange = new Range((ulong)outputGPIOOffset, (ulong)numberOfOutputGPIOs);
            }

            var innerGPIOConnections = new Dictionary<int, IGPIO>();
            for(int i = 0; i < numberOfOutputGPIOs; i++)
            {
                innerGPIOConnections[i] = new GPIO();
            }

            Connections = new ReadOnlyDictionary<int, IGPIO>(innerGPIOConnections);
        }

        public void Reset()
        {
            connection?.Reset();
        }

        public void OnGPIO(int number, bool value)
        {
            // Connection can be null here because OnGPIO is called during initialization
            // for each input connection
            connection?.SendGPIO((int)inputGPIOOffset + number, value);
        }

        public virtual void OnConnectionAttached(CoSimulationConnection connection)
        {
            this.connection = connection;
            this.connection.RegisterOnGPIOReceive(ReceiveGPIOChange, outputGPIORange);
        }

        public virtual void OnConnectionDetached(CoSimulationConnection connection)
        {
            this.connection.UnregisterOnGPIOReceive(outputGPIORange);
            this.connection = null;
        }

        public byte ReadByte(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(8, offset))
            {
                return 0;
            }
            return (byte)connection.Read(ActionType.ReadFromBusByte, offset);
        }

        public ushort ReadWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(16, offset))
            {
                return 0;
            }
            return (ushort)connection.Read(ActionType.ReadFromBusWord, offset);
        }

        public uint ReadDoubleWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(32, offset))
            {
                return 0;
            }
            return (uint)connection.Read(ActionType.ReadFromBusDoubleWord, offset);
        }

        public ulong ReadQuadWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(64, offset))
            {
                return 0;
            }
            return connection.Read(ActionType.ReadFromBusQuadWord, offset);
        }

        public void WriteByte(long offset, byte value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(8, offset, value))
            {
                connection.Write(ActionType.WriteToBusByte, offset, value);
            }
        }

        public void WriteWord(long offset, ushort value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(16, offset, value))
            {
                connection.Write(ActionType.WriteToBusWord, offset, value);
            }
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(32, offset, value))
            {
                connection.Write(ActionType.WriteToBusDoubleWord, offset, value);
            }
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(64, offset, value))
            {
                connection.Write(ActionType.WriteToBusQuadWord, offset, value);
            }
        }

        public virtual void ReceiveGPIOChange(int coSimNumber, bool value)
        {
            var localNumber = coSimNumber - (int)outputGPIORange.StartAddress;
            if (!Connections.TryGetValue(localNumber, out var gpioConnection))
            {
                 this.Log(LogLevel.Warning, "Unhandled interrupt: '{0}'", localNumber);
                 return;
            }

            gpioConnection.Set(value);
        }

        public void Dispose()
        {
            connection?.DetachFrom(this);
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        public string ConnectionParameters => connection?.ConnectionParameters ?? "";
        public void Connect()
        {
            AssureIsConnected();
            connection.Connect();
        }

        public void SetAbsoluteAddress(ulong address)
        {
            absoluteAddress = address;
        }

        public string SimulationContextLinux
        {
            get => connection.SimulationContextLinux;
            set
            {
                AssureIsConnected();
                connection.SimulationContextLinux = value;
            }
        }

        public string SimulationContextWindows
        {
            get => connection.SimulationContextWindows;
            set
            {
                AssureIsConnected();
                connection.SimulationContextWindows = value;
            }
        }

        public string SimulationContextMacOS
        {
            get => connection.SimulationContextMacOS;
            set
            {
                AssureIsConnected();
                connection.SimulationContextMacOS = value;
            }
        }

        public string SimulationContext
        {
            get => connection.SimulationContext;
            set
            {
                AssureIsConnected();
                connection.SimulationContext = value;
            }
        }

        public string SimulationFilePathLinux
        {
            get => connection.SimulationFilePathLinux;
            set
            {
                AssureIsConnected();
                connection.SimulationFilePathLinux = value;
            }
        }

        public string SimulationFilePathWindows
        {
            get => connection.SimulationFilePathWindows;
            set
            {
                AssureIsConnected();
                connection.SimulationFilePathWindows = value;
            }
        }

        public string SimulationFilePathMacOS
        {
            get => connection.SimulationFilePathMacOS;
            set
            {
                AssureIsConnected();
                connection.SimulationFilePathMacOS = value;
            }
        }

        // The following constant should be in sync with a time unit defined in the `renode` SystemVerilog module.
        // It allows using simulation time instead of a number of clock ticks.
        public const long VerilogTimeunitFrequency = 1000000000;
        public bool UseAbsoluteAddress { get; set; }

        private bool VerifyLength(int length, long offset, ulong? value = null)
        {
            if(length > maxWidth)
            {
                this.Log(LogLevel.Warning, "Trying to {0} {1} bits at offset 0x{2:X}{3}, but maximum length is {4}",
                        value.HasValue ? "write" : "read",
                        length,
                        offset,
                        value.HasValue ? $" (value 0x{value})" : String.Empty,
                        maxWidth
                );
                return false;
            }
            return true;
        }

        private void AssureIsConnected(string message = null)
        {
            if(connection == null)
            {
                throw new RecoverableException("CoSimulatedPeripheral is not attached to a CoSimulationConnection.");
            }
        }

        protected CoSimulationConnection connection;
        protected const ulong LimitBuffer = 1000000;
        protected const int DefaultTimeout  = 3000;
        readonly protected Range outputGPIORange;

        private int maxWidth;
        private int inputGPIOOffset;
        private ulong absoluteAddress = 0;
        private const string LimitTimerName = "CoSimulationIntegrationClock";
    }
}
