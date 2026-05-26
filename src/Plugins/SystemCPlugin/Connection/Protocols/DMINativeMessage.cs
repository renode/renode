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
    // Any change MUST be mirrored in struct dmi_native_message in renode_bridge.h
    // or communication will not work correctly.
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DMINativeMessage
    {
        public DMINativeMessage(RenodeAction actionId, DmiAccess dmiAccess, ulong startAddress, ulong endAddress, ulong pointer)
        {
            ActionId = actionId;
            DmiAccess = dmiAccess;
            StartAddress = startAddress;
            EndAddress = endAddress;
            Pointer = pointer;
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
                this = (DMINativeMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(DMINativeMessage));
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
            return $"RenodeMessage [{ActionId}@{StartAddress}:{EndAddress}]";
        }

        public readonly RenodeAction ActionId;
        public readonly DmiAccess DmiAccess;
        public readonly ulong StartAddress;
        public readonly ulong EndAddress;
        public readonly ulong Pointer;
    }
}
