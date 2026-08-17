//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Logging.Backends;

namespace Antmicro.Renode.NativeInterface
{
    public unsafe class NativeExportsBackend : TextBackend
    {
        public NativeExportsBackend(delegate* unmanaged<void*, int, long, byte*, byte*, void> handler = null, void* opaque = null)
        {
            Handler = handler;
            Opaque = opaque;
        }

        public override void Log(LogEntry entry, Logger.TimestampType timestampType)
        {
            if(Handler == null)
            {
                return;
            }

            var message = Marshal.StringToHGlobalAnsi(entry.Message);
            var messagePointer = (byte*)message.ToPointer();

            var objectName = Marshal.StringToHGlobalAnsi(entry.ObjectName);
            var objectNamePointer = (byte*)objectName.ToPointer();

            Handler(Opaque, entry.Type.NumericLevel, entry.Time.Ticks, objectNamePointer, messagePointer);

            Marshal.FreeHGlobal(message);
            Marshal.FreeHGlobal(objectName);
        }

        public delegate* unmanaged<void*, int, long, byte*, byte*, void> Handler { get; set; }
        public void* Opaque { get; set; }
    }
}