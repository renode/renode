//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Text;
using System.Reflection;
using System.Runtime.InteropServices;

using Antmicro.Migrant;
using Antmicro.Renode.Analyzers;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.NativeInterface
{
    [Transient]
    public unsafe class NativeExportsUartAnalyzer : BasicPeripheralBackendAnalyzer<UARTBackend>, IExternal
    {
        public NativeExportsUartAnalyzer(delegate* unmanaged<void*, byte, void> readHandler = null, void* opaque = null)
        {
            ReadHandler = readHandler;
            Opaque = opaque;
            // We need to keep the reference to this for it to not be collected by GC
            InternalWriteCallback = new WriteCallbackType(ReadChar);
            WriteCallback = (delegate* unmanaged<byte, void>)Marshal.GetFunctionPointerForDelegate(InternalWriteCallback);
        }

        public override void AttachTo(UARTBackend backend)
        {
            base.AttachTo(backend);
            uart = backend.UART;
        }

        public override void Show()
        {
            uart.CharReceived += WriteChar;
            visible = true;
        }

        public override void Hide()
        {
            uart.CharReceived -= WriteChar;
            visible = false;
        }

        public override void Clear()
        {
        }

        public delegate* unmanaged<void*, byte, void> ReadHandler { get; set; }

        public delegate* unmanaged<byte, void> WriteCallback {get; private set;}

        public void* Opaque { get; set; }

        private void WriteChar(byte value)
        {
            if(ReadHandler == null)
            {
                return;
            }
            ReadHandler(Opaque, value);
        }

        private void ReadChar(byte value)
        {
            if(uart == null)
            {
                Console.Error.WriteLine("Tried to write to uart device, but no uart is attached");
                return;
            }
            if(!visible)
            {
                return;
            }
            uart.WriteChar(value);

        }

        private IUART uart;
        private bool visible;
        private delegate void WriteCallbackType(byte value);
        private WriteCallbackType InternalWriteCallback;
    }
}