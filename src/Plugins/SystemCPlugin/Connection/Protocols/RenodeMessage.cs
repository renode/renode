//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Runtime.InteropServices;

using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals.SystemC
{
    // WARNING: This structure is part of a binary socket protocol between C and C#.
    // Any change MUST be mirrored in struct renode_message in renode_bridge.h
    // or communication will not work correctly.
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RenodeMessage
    {
        public RenodeMessage(RenodeAction actionId, byte dataLength, byte connectionIndex, ulong address, ulong payload)
        {
            ActionId = actionId;
            DataLength = dataLength;
            ConnectionIndex = connectionIndex;
            Address = address;
            Payload = payload;
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
                this = (RenodeMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(RenodeMessage));
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
            return $"RenodeMessage [{ActionId}@{ConnectionIndex}:{Address}] {Payload}";
        }

        public bool IsSystemBusConnection() => ConnectionIndex == MainSystemBusConnectionIndex;

        public bool IsDirectConnection() => !IsSystemBusConnection();

        public byte GetDirectConnectionIndex()
        {
            if(!IsDirectConnection())
            {
                Logger.Log(LogLevel.Error, "Message for main system bus connection does not have a direct connection index.");
                return 0xff;
            }
            return (byte)(ConnectionIndex - 1);
        }

        public const int DMIAllowed = 1;
        public const int DMINotAllowed = 0;

        private const byte MainSystemBusConnectionIndex = 0;

        public readonly RenodeAction ActionId;
        public readonly byte DataLength;
        public readonly byte ConnectionIndex;
        public readonly ulong Address;
        public readonly ulong Payload;
    }
}
