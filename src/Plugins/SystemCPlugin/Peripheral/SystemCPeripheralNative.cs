using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

#if !PLATFORM_WINDOWS
using Mono.Unix.Native;
#endif

namespace Antmicro.Renode.Peripherals.SystemCNative
{
    public interface IDirectAccessPeripheral : IPeripheral
    {
        ulong ReadDirect(byte dataLength, long offset, byte connectionIndex);

        void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex);
    };


    public class SystemcLibraryLoader
    {
        private readonly IntPtr library;

        public SystemcLibraryLoader(string libraryName)
        {
            // TODO: error handling

            library = NativeLibrary.Load(libraryName);
        }

        public T GetLibrarySymbol<T>(string name) where T : class
        {
            // TODO: error handling
            IntPtr ptr = NativeLibrary.GetExport(library, name);

            return Marshal.GetDelegateForFunctionPointer<T>(ptr);
        }
    }


    public class SystemCPeripheralNative : IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, IGPIOReceiver, IDirectAccessPeripheral, IDisposable
    {
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate uint SystemcStartSimDelegate(int ns);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate uint TlmReadDoubleWordDelegate(long offset);

        private SystemcStartSimDelegate _systemcStartSim;
        private TlmReadDoubleWordDelegate _readDoubleWord;


        public SystemCPeripheralNative(IMachine machine, string libName, long frequency)
        {
            // TODO: error handling

            var loader = new SystemcLibraryLoader(libName);
            _systemcStartSim = loader.GetLibrarySymbol<SystemcStartSimDelegate>("systemc_start_sim");
            _readDoubleWord = loader.GetLibrarySymbol<TlmReadDoubleWordDelegate>("tlm_read_double_word");

            systemcTimer = new LimitTimer(machine.ClockSource, frequency, this, nameof(systemcTimer), eventEnabled: true, enabled: true, limit: 10);
            systemcTimer.LimitReached += delegate
            {
                _systemcStartSim((int)(10e9 / frequency));
            };
        }

        public ulong ReadQuadWord(long offset)
        {
            //
            return 0;
        }

        public void WriteRegister(byte dataLength, long offset, ulong value, byte connectionIndex = 0)
        {
            //
        }

        public void Dispose()
        {
            //
        }

        public void Reset()
        {
            //
        }

        public void OnGPIO(int number, bool value)
        {
            //
        }

        public void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            //
        }

        public ulong ReadDirect(byte dataLength, long offset, byte connectionIndex)
        {
            //
            return 0;
        }

        public ulong ReadRegister(byte dataLength, long offset, byte connectionIndex = 0)
        {
            //
            return 0;
        }

        public byte ReadByte(long offset)
        {
            //
            Console.WriteLine("ReadByte");
            return 0;
        }

        public void WriteWord(long offset, ushort value)
        {
            //
        }

        public ushort ReadWord(long offset)
        {
            //
            Console.WriteLine("ReadWord");
            return 0;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            //
        }

        public uint ReadDoubleWord(long offset)
        {
            return _readDoubleWord(offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            //
        }

        public void WriteByte(long offset, byte value)
        {
            //
        }

        public void AddDirectConnection(byte connectionIndex, IDirectAccessPeripheral target)
        {
            //
        }

        private readonly LimitTimer systemcTimer;
    }
}
