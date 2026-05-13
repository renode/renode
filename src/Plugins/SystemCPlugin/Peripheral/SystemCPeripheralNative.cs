//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Binding;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class SystemCPeripheralNative : IDisposable, IBytePeripheral,
        IWordPeripheral, IDoubleWordPeripheral, IQuadWordPeripheral,
        INumberedGPIOOutput, IGPIOReceiver
    {
        public SystemCPeripheralNative(IMachine machine, ulong simulationStepInNs, int numberOfConnections = DefaultNumberOfConnections)
        {
            sysbus = machine.GetSystemBus(this);
            systemcTimer = new LimitTimer(machine.ClockSource, FREQUENCY, this, nameof(systemcTimer), eventEnabled: true, enabled: false, limit: simulationStepInNs);
            systemcTimer.LimitReached += delegate
            {
                SystemcStartSim((int)(simulationStepInNs));
            };

            this.numberOfConnections = numberOfConnections;
            var innerConnections = new Dictionary<int, IGPIO>();
            for(int i = 0; i < numberOfConnections; i++)
            {
                innerConnections[i] = new GPIO();
            }
            Connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);
        }

        public void Dispose()
        {
            binder?.Dispose();
        }

        public void Reset()
        {
            if(binder != null)
            {
                return;
            }
            SystemcReset();
        }

        public byte ReadByte(long offset)
        {
            return (byte)TlmRead(1, (ulong)offset, out var dmiAllowed);
        }

        public void WriteByte(long offset, byte value)
        {
            TlmWrite(1, (long)value, (ulong)offset, out var dmiAllowed);
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)TlmRead(2, (ulong)offset, out var dmiAllowed);
        }

        public void WriteWord(long offset, ushort value)
        {
            TlmWrite(2, (long)value, (ulong)offset, out var dmiAllowed);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)TlmRead(4, (ulong)offset, out var dmiAllowed);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            TlmWrite(4, (long)value, (ulong)offset, out var dmiAllowed);
        }

        public ulong ReadQuadWord(long offset)
        {
            return (ulong)TlmRead(8, (ulong)offset, out var dmiAllowed);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            TlmWrite(8, (long)value, (ulong)offset, out var dmiAllowed);
        }

        public void OnGPIO(int number, bool value)
        {
            if(binder == null)
            {
                return;
            }

            if(number > numberOfConnections)
            {
                this.Log(LogLevel.Error, "Peripheral doesn't have GPIO number {0} (max: {1})", number, numberOfConnections);
                return;
            }

            Connections[number].Set(value);
            GpioWrite(number, value);
        }

        [Export]
        public void InvalidateTranslationBlocks(ulong startAddress, ulong endAddress)
        {
            foreach(var cpu in sysbus.GetCPUs().OfType<TranslationCPU>())
            {
                cpu.OrderTranslationBlocksInvalidation(new IntPtr((long)startAddress), new IntPtr((long)endAddress));
            }
        }

        [Export]
        public void ReadBytesFromBus(ulong address, IntPtr data, int count)
        {
            var bytes = sysbus.ReadBytes(address, count, context: this);
            Marshal.Copy(bytes, 0, data, count);
        }

        [Export]
        public void WriteBytesToBus(ulong address, IntPtr data, int count)
        {
            var bytes = new byte[count];
            Marshal.Copy(data, bytes, 0, count);
            sysbus.WriteBytes(bytes, address, context: this);
        }

        [Export]
        public int GetDirectMemPtr(ulong address, out ulong startAddress, out ulong endAddress, out IntPtr mappedAddress)
        {
            startAddress = 0;
            endAddress = 0;
            mappedAddress = IntPtr.Zero;

            var targetMemory = sysbus.FindMemory(address);
            if(!(targetMemory?.GetFileMappingParameters(address) is FileMappingParameters mapping))
            {
                return 0;
            }

            startAddress = mapping.StartAddress;
            endAddress = mapping.EndAddress;
            mappedAddress = mapping.MappedAddress;
            return 1;
        }

        [Export]
        public void UpdateGPIOConnections(int number, int value)
        {
            if(number > numberOfConnections)
            {
                this.Log(LogLevel.Error, "Peripheral doesn't have GPIO number {0} (max: {1})", number, numberOfConnections);
                return;
            }

            Connections[number].Set(value == 0 ? false : true);
        }

        public string SimulationFilePathLinux
        {
            get => simulationFilePath;
            set
            {
                if(RuntimeInfo.IsLinux())
                {
                    SimulationFilePath = value;
                }
            }
        }

        public string SimulationFilePathWindows
        {
            get => simulationFilePath;
            set
            {
                if(RuntimeInfo.IsWindows())
                {
                    SimulationFilePath = value;
                }
            }
        }

        public string SimulationFilePath
        {
            get => simulationFilePath;
            set
            {
                if(String.IsNullOrWhiteSpace(value))
                {
                    var message = "SimulationFilePath can't be empty!";
                    this.Log(LogLevel.Error, message);
                    throw new RecoverableException(message);
                }

                if(!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    var message = $"Peripheral is already co-simulated using: {simulationFilePath}";
                    this.Log(LogLevel.Error, message);
                    throw new RecoverableException(message);
                }

                simulationFilePath = value;

                InitBinder();
                SystemcInit();
                systemcTimer.Enabled = true;

                SystemcSetNonblockingRead(NonBlockingRead);
                SystemcSetNonblockingWrite(NonBlockingWrite);
            }
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        public bool NonBlockingRead
        {
            get => nonBlockingRead;
            set
            {
                nonBlockingRead = value;
                if(binder == null)
                {
                    return;
                }
                SystemcSetNonblockingRead(value);
            }
        }

        public bool NonBlockingWrite
        {
            get => nonBlockingWrite;
            set
            {
                nonBlockingWrite = value;
                if(binder == null)
                {
                    return;
                }
                SystemcSetNonblockingWrite(value);
            }
        }

        private void InitBinder()
        {
            if(!Misc.TryCopyToTemporaryFile(simulationFilePath, out var copiedSimulationFilePath))
            {
                throw new RecoverableException($"Cannot find library {simulationFilePath}");
            }

            try
            {
                binder = new NativeBinder(this, simulationFilePath);
            }
            catch(InvalidOperationException)
            {
                throw new RecoverableException($"Cannot find library {simulationFilePath}");
            }
        }

        private NativeBinder binder;
        private string simulationFilePath;
        private bool nonBlockingRead;
        private bool nonBlockingWrite;
        private readonly IBusController sysbus;

#pragma warning disable 649

        [Import(UseExceptionWrapper = false)]
        private readonly Action SystemcInit;

        [Import(UseExceptionWrapper = false)]
        private readonly Action SystemcReset;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<int> SystemcStartSim;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<bool> SystemcSetNonblockingRead;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<bool> SystemcSetNonblockingWrite;

        [Import(UseExceptionWrapper = false)]
        private readonly TlmReadDelegate TlmRead;

        [Import(UseExceptionWrapper = false)]
        private readonly TlmWriteDelegate TlmWrite;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<int, bool> GpioWrite;

#pragma warning restore 649

        private readonly LimitTimer systemcTimer;
        private readonly int numberOfConnections;
        private const int FREQUENCY = (int)1e9;

        // Set to this value to maintain compatibility with the non-native peripheral model
        // See: NumberOfGPIOPins in SystemCPeripheral
        private const int DefaultNumberOfConnections = 64;

        // Explicit types for out parameters.
        private delegate ulong TlmReadDelegate(ulong size, ulong offset, [MarshalAs(UnmanagedType.I1)] out bool dmiAllowed);

        private delegate ulong TlmWriteDelegate(ulong size, long value, ulong offset, [MarshalAs(UnmanagedType.I1)] out bool dmiAllowed);
    }
}
