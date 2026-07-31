//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;

using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `message_t` in C
    public readonly struct Message
    {
        public static Message ClientInitiated(ushort id, IEnumerable<byte> data)
        {
            return new Message((ushort)(id | ClientInitiatedMask), data.ToArray());
        }

        public static Message ServerInitiated(IEnumerable<byte> data)
        {
            return new Message((ushort)(GetNextId() & unchecked((ushort)~ClientInitiatedMask)), data.ToArray());
        }

        public static bool TryDecodeHeader(List<byte> data, out Message message)
        {
            if(data.Count < HeaderSize)
            {
                message = default;
                return false;
            }

            var dataSpan = CollectionsMarshal.AsSpan(data);
            var id = BitConverter.ToUInt16(dataSpan[..sizeof(ushort)]);
            var dataSize = BitConverter.ToUInt32(dataSpan[sizeof(ushort)..][..sizeof(uint)]);
            message = new Message(id, dataSize);
            return true;
        }

        public IEnumerable<byte> ToBytes() => BitConverter.GetBytes(ID).Concat(BitConverter.GetBytes((uint)Data.Length)).Concat(Data);

        public override string ToString()
        {
            if(Data.Length == 0)
            {
                return $"{nameof(Message)}(ID=0x{ID:X}, ClientInitiated={IsClientInitiated}, Size={DataSize})";
            }
            else
            {
                return $"{nameof(Message)}(ID=0x{ID:X}, ClientInitiated={IsClientInitiated}, Size={DataSize}, Data={Misc.PrettyPrintCollectionHex(Data)})";
            }
        }

        public Message WithData(IList<byte> data)
        {
            return new Message(ID, data.Take((int)DataSize).ToArray());
        }

        public ushort ID { get; }

        public uint DataSize { get; }

        public byte[] Data { get; }

        public bool IsClientInitiated => (ID & ClientInitiatedMask) == ClientInitiatedMask;

        public const int HeaderSize = sizeof(ushort) + sizeof(uint);

        private static ushort GetNextId()
        {
            lock(nextIdLock)
            {
                return nextId++;
            }
        }

        private static ushort nextId;
        private static readonly object nextIdLock = new object();

        private Message(ushort id, byte[] data)
        {
            ID = id;
            DataSize = (uint)data.Length;
            Data = data;
        }

        private Message(ushort id, uint dataSize)
        {
            ID = id;
            DataSize = dataSize;
            Data = [];
        }

        private const ushort ClientInitiatedMask = 0x8000;
    }
}
