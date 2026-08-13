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

using Antmicro.Renode.Exceptions;

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `message_t` in C
    public class Message
    {
        public static bool TryDecodeHeader(List<byte> data, out Message message)
        {
            if(data.Count < HeaderSize)
            {
                message = default;
                return false;
            }

            var dataSpan = CollectionsMarshal.AsSpan(data);
            var id = BitConverter.ToUInt16(dataSpan[..sizeof(ushort)]);
            var payloadSize = BitConverter.ToInt32(dataSpan[sizeof(ushort)..][..sizeof(uint)]);

            if(payloadSize < MessagePayload.HeaderSize)
            {
                // TODO: Modify the protocol definition to make it impossible
                throw new RecoverableException($"Invalid payload size received: {payloadSize}");
            }

            message = new Message(id, payloadSize);
            data.RemoveRange(0, HeaderSize);

            return true;
        }

        // It overrides the MSB of the given id
        public Message(bool isExternallyInitiated, ushort id, MessagePayload payload)
        {
            Id = (ushort)(isExternallyInitiated ? id | ExternallyInitiatedMask : id & ~ExternallyInitiatedMask);
            PayloadSize = payload.GetSize();
            Payload = payload;
        }

        public Message(ushort id, MessagePayload payload)
        {
            Id = id;
            PayloadSize = payload.GetSize();
            Payload = payload;
        }

        public bool TryDecodePayload(List<byte> data)
        {
            if(data.Count < PayloadSize)
            {
                return false;
            }

            var dataSpan = CollectionsMarshal.AsSpan(data);
            var cmd = (Command)BitConverter.ToUInt16(dataSpan[..sizeof(ushort)]);
            Payload = new MessagePayload(cmd, (CommandType)dataSpan[2], dataSpan[..PayloadSize][MessagePayload.HeaderSize..].ToArray());

            data.RemoveRange(0, PayloadSize);

            return true;
        }

        public IEnumerable<byte> ToBytes() => BitConverter.GetBytes(Id).Concat(BitConverter.GetBytes(PayloadSize)).Concat(Payload.ToBytes());

        public override string ToString() => ToCustomString();

        public string ToCustomString(bool withData = true)
        {
            var initiator = IsExternallyInitiated ? "ext" : "int";

            return $"{nameof(Message)}(Id=0x{Id:X}({initiator}), Size={PayloadSize}, {Payload.ToCustomString(withData)})";
        }

        public ushort Id { get; }

        public int PayloadSize { get; }

        public MessagePayload Payload { get; private set; }

        public bool IsExternallyInitiated => (Id & ExternallyInitiatedMask) == ExternallyInitiatedMask;

        public const int HeaderSize = sizeof(ushort) + sizeof(uint);

        public const ushort ExternallyInitiatedMask = 0x8000;

        private Message(ushort id, int payloadSize)
        {
            Id = id;
            PayloadSize = payloadSize;
        }
    }
}
