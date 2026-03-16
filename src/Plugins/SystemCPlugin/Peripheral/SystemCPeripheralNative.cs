//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Binding;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class SystemCPeripheralNative : IDisposable, IBytePeripheral,
        IWordPeripheral, IDoubleWordPeripheral, IQuadWordPeripheral
    {
        public SystemCPeripheralNative(IMachine machine, ulong simulationStepInNs)
        {
            systemcTimer = new LimitTimer(machine.ClockSource, FREQUENCY, this, nameof(systemcTimer), eventEnabled: true, enabled: false, limit: simulationStepInNs);
            systemcTimer.LimitReached += delegate
            {
                SystemcStartSim((int)(simulationStepInNs));
            };
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

#pragma warning restore 649

        private readonly LimitTimer systemcTimer;
        private const int FREQUENCY = (int)1e9;
    }
}
