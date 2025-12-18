//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Timers;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class SystemcLibraryLoader
    {
        public SystemcLibraryLoader(string libraryName)
        {
            this.libraryName = libraryName;
            this.library = NativeLibrary.Load(libraryName);
        }

        public T GetLibrarySymbol<T>(string name) where T : class
        {
            IntPtr ptr = NativeLibrary.GetExport(library, name);

            return Marshal.GetDelegateForFunctionPointer<T>(ptr);
        }

        public void Unload()
        {
            NativeLibrary.Free(library);
            library = IntPtr.Zero;
        }

        private IntPtr library;
        private readonly string libraryName;
    }

    public class SystemCPeripheralNative : IDisposable, IBytePeripheral,
        IWordPeripheral, IDoubleWordPeripheral, IQuadWordPeripheral
    {
        public SystemCPeripheralNative(IMachine machine, string libName, ulong frequency)
        {
            libraryLoader = new SystemcLibraryLoader(libName);

            _systemcInit = libraryLoader.GetLibrarySymbol<SystemcInitDelegate>("systemc_init");
            _systemcReset = libraryLoader.GetLibrarySymbol<SystemcResetDelegate>("systemc_reset");
            _systemcStartSim = libraryLoader.GetLibrarySymbol<SystemcStartSimDelegate>("systemc_start_sim");
            _readInternal = libraryLoader.GetLibrarySymbol<TlmReadInternalDelegate>("tlm_read");
            _writeInternal = libraryLoader.GetLibrarySymbol<TlmWriteInternalDelegate>("tlm_write");

            systemcTimer = new LimitTimer(machine.ClockSource, frequency, this, nameof(systemcTimer), eventEnabled: true, enabled: true, limit: 10);
            systemcTimer.LimitReached += delegate
            {
                _systemcStartSim((int)(10e9 / frequency));
            };

            _systemcInit();
        }

        public void Dispose()
        {
            libraryLoader.Unload();
        }

        public void Reset()
        {
            _systemcReset();
        }

        public byte ReadByte(long offset)
        {
            return (byte)_readInternal(1, offset);
        }

        public void WriteByte(long offset, byte value)
        {
            _writeInternal(1, (long)value, offset);
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)_readInternal(4, offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            _writeInternal(4, (long)value, offset);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)_readInternal(8, offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            _writeInternal(8, (long)value, offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            _writeInternal(16, (long)value, offset);
        }

        public ulong ReadQuadWord(long offset)
        {
            return (ulong)_readInternal(16, offset);
        }

        private readonly LimitTimer systemcTimer;
        private readonly SystemcLibraryLoader libraryLoader;

        private readonly SystemcInitDelegate _systemcInit;
        private readonly SystemcResetDelegate _systemcReset;
        private readonly SystemcStartSimDelegate _systemcStartSim;
        private readonly TlmReadInternalDelegate _readInternal;
        private readonly TlmWriteInternalDelegate _writeInternal;

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void SystemcInitDelegate();

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void SystemcResetDelegate();

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate uint SystemcStartSimDelegate(int ns);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate ulong TlmReadInternalDelegate(uint size, long offset);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate ulong TlmWriteInternalDelegate(uint size, long value, long offset);
    }
}
