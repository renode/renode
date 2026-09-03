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

using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
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

        public static MessagePayload FromStruct<T>(Command command, CommandType type, T payload) where T : struct
        {
            return new MessagePayload(command, type, payload.AsRawBytes());
        }

        public static MessagePayload Event(Command command, int eventId, byte[] payload)
        {
            return new MessagePayload(command, CommandType.EventRequest, BitConverter.GetBytes(eventId).Concat(payload).ToArray());
        }

        public static MessagePayload Event<T>(Command command, int eventId, T payload) where T : struct
        {
            return Event(command, eventId, payload.AsRawBytes());
        }

        public static MessagePayload Event<T>(Command command, int eventId, T payloadHeader, byte[] data) where T : struct
        {
            return new MessagePayload(command, CommandType.EventRequest,
            BitConverter.GetBytes(eventId)
                .Concat(payloadHeader.AsRawBytes())
                .Concat(data).ToArray());
        }

        public static MessagePayload Request(Command command, byte[] payload)
        {
            return new MessagePayload(command, CommandType.Request, payload);
        }

        public static MessagePayload Request(Command command, string payload)
        {
            var payloadBytes = Encoding.UTF8.GetBytes(payload);
            return new MessagePayload(command, CommandType.Request, payloadBytes.Length.AsRawBytes().Concat(payloadBytes).ToArray());
        }

        public static MessagePayload Request<T>(Command command, T payload) where T : struct
        {
            return new MessagePayload(command, CommandType.Request, payload.AsRawBytes());
        }

        public MessagePayload(Command cmd, CommandType type, byte[] data)
        {
            Command = cmd;
            Type = type;
            Data = data;
        }

        public IEnumerable<byte> ToBytes() => BitConverter.GetBytes((ushort)Command).Concat([(byte)Type]).Concat(Data);

        public int GetSize() => HeaderSize + Data.Length;

        public override string ToString() => ToCustomString();

        public string ToCustomString(bool withData = true)
        {
            var dataString = withData ? Misc.PrettyPrintCollectionHex(Data) : "[...]";

            return $"{nameof(MessagePayload)}(Command={Command}, Type={Type}, {dataString})";
        }

        public void ThrowOnError(Command identifier)
        {
            if(TryGetErrorMessage(out var message, identifier))
            {
                throw new RecoverableException(message);
            }
        }

        public bool LogOnError(Command identifier, IEmulationElement parent)
        {
            var isError = TryGetErrorMessage(out var message, identifier);
            if(isError)
            {
                parent.Log(LogLevel.Error, message);
            }
            return !isError;
        }

        public bool TryGetErrorMessage(out string message, Command identifier)
        {
            switch(Type)
            {
            case CommandType.Success:
                // Do nothing on success
                message = null;
                return false;
            case CommandType.Error:
                try
                {
                    message = $"Command {identifier} failed with: {Encoding.UTF8.GetString(Data)}";
                }
                catch(ArgumentException e)
                {
                    message = $"Cannot decode an error response for command {identifier} due to: {e.Message} (raw data: {Data.ToLazyHexString()})";
                }
                break;
            case CommandType.InvalidCommand:
                message = $"Command {identifier} is not supported by the connected external";
                break;
            default:
                message = $"Unexpected response type: {Type} for command {identifier}";
                break;
            }
            return true;
        }

        public Command Command { get; }

        public CommandType Type { get; }

        public byte[] Data { get; }

        public const int HeaderSize = sizeof(Command) + sizeof(CommandType);
    }
}
