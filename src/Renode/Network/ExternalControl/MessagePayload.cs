//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `message_payload_t` in C
    public readonly struct MessagePayload
    {
        public static MessagePayload Success(Command command, byte[] data)
        {
            return new MessagePayload(command, CommandType.Success, data);
        }

        public static MessagePayload Success(Command command, string data)
        {
            return new MessagePayload(command, CommandType.Success, Encoding.UTF8.GetBytes(data));
        }

        public static MessagePayload Success(Command command)
        {
            return Success(command, Array.Empty<byte>());
        }

        public static MessagePayload InvalidCommand(Command command)
        {
            return new MessagePayload(command, CommandType.InvalidCommand, []);
        }

        public static MessagePayload Error(Command command, string message)
        {
            return new MessagePayload(command, CommandType.Error, Encoding.UTF8.GetBytes(message));
        }

        public static MessagePayload Error(string message)
        {
            return new MessagePayload((Command)0x0, CommandType.Error, Encoding.UTF8.GetBytes(message));
        }

        public static MessagePayload Event<T>(Command command, int eventId, T payload) where T : struct
        {
            return new MessagePayload(command, CommandType.EventRequest, BitConverter.GetBytes(eventId).Concat(payload.AsRawBytes()).ToArray());
        }

        public static bool TryDecode(Message header, out MessagePayload cmdData)
        {
            if(header.Data.Length < HeaderSize)
            {
                cmdData = default;
                return false;
            }

            Span<byte> data = header.Data;
            var cmd = (Command)BitConverter.ToUInt16(data[..sizeof(ushort)]);
            cmdData = new MessagePayload(cmd, (CommandType)data[2], data[HeaderSize..].ToArray());
            return true;
        }

        public IEnumerable<byte> ToBytes() => BitConverter.GetBytes((ushort)Command).Concat([(byte)Type]).Concat(Data);

        public override string ToString() => $"{nameof(MessagePayload)}(Command={Command}, Type={Type}, Data={Misc.PrettyPrintCollectionHex(Data)})";

        public Command Command { get; }

        public CommandType Type { get; }

        public byte[] Data { get; }

        public const int HeaderSize = sizeof(Command) + sizeof(CommandType);

        private MessagePayload(Command cmd, CommandType type, byte[] data)
        {
            Command = cmd;
            Type = type;
            Data = data;
        }
    }
}
