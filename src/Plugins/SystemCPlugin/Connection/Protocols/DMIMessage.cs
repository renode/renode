//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Runtime.InteropServices;

namespace Antmicro.Renode.Peripherals.SystemC
{
    // WARNING: This structure is part of a binary socket protocol between C and C#.
    // Any change MUST be mirrored in struct dmi_message in renode_bridge.h
    // or communication will not work correctly.
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DMIMessage
    {
        public DMIMessage(RenodeAction actionId, byte allowed, FileMappingParameters mapping)
        {
            ActionId = actionId;
            Allowed = allowed;
            Mapping = mapping;
        }

        public byte[] Serialize()
        {
            var size = Marshal.SizeOf(this);
            var result = new byte[size];
            var handler = default(GCHandle);

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
            var handler = default(GCHandle);
            try
            {
                handler = GCHandle.Alloc(message, GCHandleType.Pinned);
                this = (DMIMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(DMIMessage));
            }
            finally
            {
                if(handler.IsAllocated)
                {
                    handler.Free();
                }
            }
        }

        public override string ToString()
        {
            return $"DMIMessage [{ActionId}@{Mapping.StartAddress}:{Mapping.EndAddress}]";
        }

        public readonly RenodeAction ActionId;
        public readonly byte Allowed;
        public readonly FileMappingParameters Mapping;
    }
}
