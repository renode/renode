//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
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
        public SystemCPeripheralNative(IMachine machine, ulong frequency, ulong limitBuffer)
        {
            systemcTimer = new LimitTimer(machine.ClockSource, frequency, this, nameof(systemcTimer), eventEnabled: true, enabled: false, limit: limitBuffer);
            systemcTimer.LimitReached += delegate
            {
                SystemcStartSim((int)(1e9 * limitBuffer / frequency));
            };

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
                if (String.IsNullOrWhiteSpace(value))
                {
                    var message = "SimulationFilePath can't be empty!";
                    this.Log(LogLevel.Error, message);

                    return;
                }

                if (!String.IsNullOrWhiteSpace(simulationFilePath))
                {
                    var message = $"Peripheral is already co-simulated using: {simulationFilePath}";
                    this.Log(LogLevel.Error, message);
                }

                simulationFilePath = value;

                InitBinder();
                SystemcInit();
                systemcTimer.Enabled = true;
            }
        }

        private void InitBinder()
        {
            string resourceFileName = Path.GetFileName(simulationFilePath);;
            string resourceFilePath;

            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                if (assembly.TryFromResourceToTemporaryFile(simulationFilePath, out resourceFilePath, resourceFileName))
                {
                    binder = new NativeBinder(this, resourceFilePath);
                    break;
                }
            }
        }

        public void Dispose()
        {
            binder.Dispose();
        }

        public void Reset()
        {
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
            return (ushort)TlmRead(4, (ulong)offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            TlmWrite(4, (long)value, (ulong)offset);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)TlmRead(8, (ulong)offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            TlmWrite(8, (long)value, (ulong)offset);
        }

        public ulong ReadQuadWord(long offset)
        {
            return (ulong)TlmRead(16, (ulong)offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            TlmWrite(16, (long)value, (ulong)offset);
        }

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
        private NativeBinder binder;
        private string simulationFilePath;
    }
}
