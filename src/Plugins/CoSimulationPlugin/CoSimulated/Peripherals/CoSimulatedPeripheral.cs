//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class CoSimulatedPeripheral : ICoSimulationConnectible, IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, IBusPeripheral, IDisposable, INumberedGPIOOutput, IGPIOReceiver, IAbsoluteAddressAware
    {
        public CoSimulatedPeripheral(Machine machine, int maxWidth = 64, bool useAbsoluteAddress = false, long frequency = VerilogTimeunitFrequency,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int mainListenPort = 0, int asyncListenPort = 0, bool createConnection = true,
            ulong renodeToCosimSignalsOffset = 0, Range? cosimToRenodeSignalRange = null, int renodeToCosimIndex = 0, int cosimToRenodeIndex = 0, string stdoutFile = null, string stderrFile = null, string renodeLogLevel = null)
        {
            UseAbsoluteAddress = useAbsoluteAddress;
            this.maxWidth = maxWidth;
            this.renodeToCosimSignalsOffset = renodeToCosimSignalsOffset;
            this.cosimToRenodeSignalRange = cosimToRenodeSignalRange;
            RenodeToCosimIndex = renodeToCosimIndex;
            CosimToRenodeIndex = cosimToRenodeIndex;

            if(createConnection)
            {
                connection = new CoSimulationConnection(machine, "cosimulation_connection", frequency, limitBuffer, timeout, address, mainListenPort, asyncListenPort, stdoutFile, stderrFile, renodeLogLevel);
                connection.AttachTo(this);
            }
            else
            {
                CheckNoEffectConstructorParam(nameof(frequency), frequency, VerilogTimeunitFrequency);
                CheckNoEffectConstructorParam(nameof(limitBuffer), limitBuffer, LimitBuffer);
                CheckNoEffectConstructorParam(nameof(timeout), timeout, DefaultTimeout);
                CheckNoEffectConstructorParam(nameof(address), address, null);
                CheckNoEffectConstructorParam(nameof(stdoutFile), stdoutFile, null);
                CheckNoEffectConstructorParam(nameof(stderrFile), stderrFile, null);
                CheckNoEffectConstructorParam(nameof(renodeLogLevel), renodeLogLevel, null);
            }

            var innerGPIOConnections = new Dictionary<int, IGPIO>();
            if(this.cosimToRenodeSignalRange.HasValue)
            {
                for(int i = 0; i < (int)this.cosimToRenodeSignalRange.Value.Size; i++)
                {
                    innerGPIOConnections[i] = new GPIO();
                }
            }

            Connections = new ReadOnlyDictionary<int, IGPIO>(innerGPIOConnections);
        }

        public void Connect()
        {
            AssureIsConnected();
            connection.Connect();
        }

        public void SetAbsoluteAddress(ulong address)
        {
            absoluteAddress = address;
        }

        public void Reset()
        {
            connection?.Reset();
        }

        public void OnGPIO(int number, bool value)
        {
            // Connection can be null here because OnGPIO is called during initialization
            // for each input connection
            connection?.SendGPIO((int)renodeToCosimSignalsOffset + number, value);
        }

        public virtual void OnConnectionAttached(CoSimulationConnection connection)
        {
            this.connection = connection;
            if(cosimToRenodeSignalRange.HasValue)
            {
                this.connection.RegisterOnGPIOReceive(ReceiveGPIOChange, cosimToRenodeSignalRange.Value);
            }
        }

        public virtual void OnConnectionDetached(CoSimulationConnection connection)
        {
            if(cosimToRenodeSignalRange.HasValue)
            {
                this.connection.UnregisterOnGPIOReceive(cosimToRenodeSignalRange.Value);
            }
            this.connection = null;
        }

        public byte ReadByte(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(8, offset))
            {
                return 0;
            }
            return (byte)connection.Read(this, ActionType.ReadFromBusByte, offset);
        }

        public ushort ReadWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(16, offset))
            {
                return 0;
            }
            return (ushort)connection.Read(this, ActionType.ReadFromBusWord, offset);
        }

        public uint ReadDoubleWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(32, offset))
            {
                return 0;
            }
            return (uint)connection.Read(this, ActionType.ReadFromBusDoubleWord, offset);
        }

        public ulong ReadQuadWord(long offset)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(!VerifyLength(64, offset))
            {
                return 0;
            }
            return connection.Read(this, ActionType.ReadFromBusQuadWord, offset);
        }

        public void WriteByte(long offset, byte value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(8, offset, value))
            {
                connection.Write(this, ActionType.WriteToBusByte, offset, value);
            }
        }

        public void WriteWord(long offset, ushort value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(16, offset, value))
            {
                connection.Write(this, ActionType.WriteToBusWord, offset, value);
            }
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(32, offset, value))
            {
                connection.Write(this, ActionType.WriteToBusDoubleWord, offset, value);
            }
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            offset = UseAbsoluteAddress ? (long)absoluteAddress : offset;
            if(VerifyLength(64, offset, value))
            {
                connection.Write(this, ActionType.WriteToBusQuadWord, offset, value);
            }
        }

        public virtual void ReceiveGPIOChange(int coSimNumber, bool value)
        {
            if(!cosimToRenodeSignalRange.HasValue)
            {
                this.Log(LogLevel.Warning, $"Received GPIO change from co-simulation, but no cosimToRenodeSignalRange is defined.");
                return;
            }

            var localNumber = coSimNumber - (int)cosimToRenodeSignalRange.Value.StartAddress;
            if(!Connections.TryGetValue(localNumber, out var gpioConnection))
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

        public bool UseAbsoluteAddress { get; set; }

        public int RenodeToCosimIndex { get; }

        public int CosimToRenodeIndex { get; }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        public string ConnectionParameters => connection?.ConnectionParameters ?? "";

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

        protected CoSimulationConnection connection;
        protected readonly Range? cosimToRenodeSignalRange;
        protected const ulong LimitBuffer = 1000000;
        protected const int DefaultTimeout  = 3000;

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

        private void AssureIsConnected()
        {
            if(connection == null)
            {
                throw new RecoverableException("CoSimulatedPeripheral is not attached to a CoSimulationConnection.");
            }
        }

        private void CheckNoEffectConstructorParam<T>(string name, T value, T defaultValue)
        {
            if(EqualityComparer<T>.Default.Equals(defaultValue, value) == false)
            {
                this.Log(LogLevel.Error, "CoSimulatedPeripheral: Parameter \"{0}\" set to {1} will be ignored, because this peripheral uses an external CoSimulationConnection (\"createConnection\" is set to false). Change the property in the relevant CoSimulationConnection instead.", name, value);
            }
        }

        private ulong absoluteAddress = 0;

        private readonly int maxWidth;
        private readonly ulong renodeToCosimSignalsOffset;
        private const string LimitTimerName = "CoSimulationIntegrationClock";
    }
}