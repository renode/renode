//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Antmicro.Renode.Debugging;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class Response
    {
        public static Response CommandFailed(Command command, string reason)
        {
            return new Response(ReturnCode.CommandFailed, command, text: reason);
        }

        public static Response FatalError(string reason)
        {
            return new Response(ReturnCode.FatalError, text: reason);
        }

        public static Response InvalidCommand(Command command)
        {
            return new Response(ReturnCode.InvalidCommand, command);
        }

        public static Response Success(Command command)
        {
            return new Response(ReturnCode.SuccessWithoutData, command);
        }

        public static Response Success(Command command, IEnumerable<byte> data)
        {
            return new Response(ReturnCode.SuccessWithData, command, data);
        }

        public static Response Success(Command command, string text)
        {
            return new Response(ReturnCode.SuccessWithData, command, text);
        }

        public static Response SuccessfulHandshake()
        {
            return new Response(ReturnCode.SuccessfulHandshake);
        }

        public static Response Event(Command command, int eventDescriptor, IEnumerable<byte> data)
        {
            return new Response(ReturnCode.AsyncEvent, command, eventDescriptor, data.ToArray());
        }

        public override string ToString()
        {
            var result = new StringBuilder("Response(")
                .Append(returnCode);

            if(command.HasValue)
            {
                result
                    .Append(", command: ")
                    .Append(command);
            }

            if(eventDescriptor != null)
            {
                result
                    .Append(", eventDescriptor: ")
                    .Append(eventDescriptor);
            }

            if(data != null)
            {
                result
                    .Append(", data: ")
                    .Append(dataIsText ? Encoding.ASCII.GetString(data) : Misc.PrettyPrintCollectionHex(data));
            }

            return result
                .Append(')')
                .ToString();
        }

        public IEnumerable<byte> GetBytes()
        {
            var response = new List<byte> { (byte)returnCode };

            if(command.HasValue)
            {
                response.Add((byte)command);
            }

            if(eventDescriptor.HasValue)
            {
                response.AddRange(((int)eventDescriptor).AsRawBytes());
            }

            if(data != null && data.Any())
            {
                response.AddRange(checked((uint)data.Length).AsRawBytes());
                response.AddRange(data);
            }

            return response;
        }

        private Response(ReturnCode returnCode)
            : this(returnCode, null, null, null)
        {
        }

        private Response(ReturnCode returnCode, string text)
            : this(returnCode, null, text)
        {
        }

        private Response(ReturnCode returnCode, Command? command, string text)
            : this(returnCode, command, null, Encoding.ASCII.GetBytes(text))
        {
            dataIsText = true;
        }

        private Response(ReturnCode returnCode, Command? command, IEnumerable<byte> data)
            : this(returnCode, command, null, data.ToArray())
        {
        }

        private Response(ReturnCode returnCode, Command? command, int? eventDescriptor = null, byte[] data = null)
        {
            // Command can be null only for FatalError and SuccessfulHandshake
            DebugHelper.Assert(command != null || returnCode == ReturnCode.FatalError || returnCode == ReturnCode.SuccessfulHandshake);
            // eventDescriptor can be null for all return codes but AsyncEvent
            DebugHelper.Assert(eventDescriptor != null || returnCode != ReturnCode.AsyncEvent);

            this.returnCode = returnCode;
            this.command = command;
            this.eventDescriptor = eventDescriptor;
            this.data = data;
            dataIsText = false;
        }

        private readonly bool dataIsText;
        private readonly Command? command;
        private readonly int? eventDescriptor;
        private readonly byte[] data;
        private readonly ReturnCode returnCode;

        // matches the return_code_t enum in tools/external_control_client/lib/renode_api.c
        private enum ReturnCode : byte
        {
            CommandFailed,
            FatalError,
            InvalidCommand,
            SuccessWithData,
            SuccessWithoutData,
            SuccessfulHandshake,
            AsyncEvent,
        }
    }
}