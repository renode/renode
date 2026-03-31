//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;

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
            return (byte)TlmRead(1, (ulong)offset);
        }

        public void WriteByte(long offset, byte value)
        {
            TlmWrite(1, (long)value, (ulong)offset);
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)TlmRead(2, (ulong)offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            TlmWrite(2, (long)value, (ulong)offset);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)TlmRead(4, (ulong)offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            TlmWrite(4, (long)value, (ulong)offset);
        }

        public ulong ReadQuadWord(long offset)
        {
            return (ulong)TlmRead(8, (ulong)offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            TlmWrite(8, (long)value, (ulong)offset);
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
            }
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        private void InitBinder()
        {
            string resourceFileName = Path.GetFileName(simulationFilePath);

            foreach(var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                if(assembly.TryFromResourceToTemporaryFile(simulationFilePath, out var resourceFilePath, resourceFileName))
                {
                    binder = new NativeBinder(this, resourceFilePath);
                    break;
                }
                else
                {
                    throw new RecoverableException($"Cannot find library {resourceFilePath}");
                }
            }
        }

        private NativeBinder binder;
        private string simulationFilePath;
        private readonly IBusController sysbus;

#pragma warning disable 649

        [Import(UseExceptionWrapper = false)]
        private readonly Action SystemcInit;

        [Import(UseExceptionWrapper = false)]
        private readonly Action SystemcReset;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<int> SystemcStartSim;

        [Import(UseExceptionWrapper = false)]
        private readonly Func<ulong, ulong, ulong> TlmRead;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<ulong, long, ulong> TlmWrite;

        [Import(UseExceptionWrapper = false)]
        private readonly Action<int, bool> GpioWrite;

#pragma warning restore 649

        private readonly LimitTimer systemcTimer;
        private readonly int numberOfConnections;
        private const int FREQUENCY = (int)1e9;

        // Set to this value to maintain compatibility with the non-native peripheral model
        // See: NumberOfGPIOPins in SystemCPeripheral
        private const int DefaultNumberOfConnections = 64;
    }
}
