//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `message_t` in C
    public class Message
    {
        public static bool TryDecodeHeader(ReadOnlySpan<byte> data, out Message message)
        {
            if(data.Length < HeaderSize)
            {
                message = default;
                return false;
            }

            var id = BitConverter.ToUInt16(data);
            var payloadSize = BitConverter.ToInt32(data[sizeof(ushort)..]);

            if(payloadSize < MessagePayload.HeaderSize)
            {
                message = default;
                return false;
            }

            message = new Message(id, payloadSize);
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

        public bool TryDecodePayload(ReadOnlySpan<byte> data)
        {
            if(data.Length < PayloadSize)
            {
                return false;
            }

            var cmd = (Command)BitConverter.ToUInt16(data);
            var type = (CommandType)data[2];
            var payload = data[..PayloadSize][MessagePayload.HeaderSize..].ToArray();
            Payload = new MessagePayload(cmd, type, payload);

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
