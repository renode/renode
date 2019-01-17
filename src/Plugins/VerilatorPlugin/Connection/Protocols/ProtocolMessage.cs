//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System.Runtime.InteropServices;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols
{
    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    public struct ProtocolMessage
    {
        public ActionNumber ActionId { get; set; }
        public ulong Address { get; set; }
        public ulong Data { get; set; }

        public byte[] Serialize()
        {
            var size = Marshal.SizeOf(this);
            var result = new byte[size];
            GCHandle handler = default(GCHandle);

            try
            {
                handler = GCHandle.Alloc(result, GCHandleType.Pinned);
                Marshal.StructureToPtr(this, handler.AddrOfPinnedObject(), false);
            }
            finally
            {
                if(handler.IsAllocated)
                {
                    handler.Free();
                }
            }

            return result;
        }

        public void Deserialize(byte[] message)
        {
            GCHandle handler = default(GCHandle);
            try
            {
                handler = GCHandle.Alloc(message, GCHandleType.Pinned);
                this = (ProtocolMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(ProtocolMessage));
            }
            finally
            {
                if(handler.IsAllocated)
                {
                    handler.Free();
                }
            }

        }
    }
}
