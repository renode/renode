//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Net.Sockets;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Packets;

namespace Antmicro.Renode.Network
{
    public static class ExternalControlServerExtensions
    {
        public static void CreateExternalControlServer(this Emulation emulation, string name, int port)
        {
            emulation.ExternalsManager.AddExternal(new ExternalControlServer(emulation, port), name);
        }
    }

    public class ExternalControlServer : IDisposable, IExternal, IEmulationElement
    {
        public ExternalControlServer(Emulation emulation, int port)
        {
            this.emulation = emulation;
            socketServerProvider.BufferSize = 0x10;

            commandHandlers = new CommandHandlerCollection();
            commandHandlers.Register(Command.RunFor, 0x0, HandleRunFor);

            socketServerProvider.ConnectionAccepted += delegate
            {
                state = State.Handshake;
                this.Log(LogLevel.Debug, "Connection established");
            };
            socketServerProvider.ConnectionClosed += delegate
            {
                commandHandlers.ClearActivation();
                state = State.NotConnected;
                this.Log(LogLevel.Debug, "Connection closed");
            };

            socketServerProvider.DataBlockReceived += OnBytesWritten;
            socketServerProvider.Start(port);

            this.Log(LogLevel.Info, "{0}: Listening on port {1}", nameof(ExternalControlServer), port);
        }

        public void Dispose()
        {
            socketServerProvider.Stop();
            state = State.Disposed;
        }

        private bool IsHeaderValid()
        {
            if(!header.HasValue)
            {
                return false;
            }

            try
            {
                if(Encoding.ASCII.GetString(header.Value.magic) != Magic)
                {
                    return false;
                }
            }
            catch(ArgumentException)
            {
                return false;
            }

            if(header.Value.dataSize > (uint)Int32.MaxValue)
            {
                return false;
            }

            return true;
        }

        private bool TryActivateCommands(List<byte> data)
        {
            foreach(var pair in data.Split(2))
            {
                var command = (Command)pair[0];
                var version = pair[1];

                if(commandHandlers.TryActivate(command, version))
                {
                    this.Log(LogLevel.Noisy, "{0} (version 0x{1:X}) activated", command, version);
                    continue;
                }

                var message = commandHandlers.TryGetVersion(command, out var expectedVersion)
                    ? $"Encountered invalid version (0x{version:X}) for {command}, expected 0x{expectedVersion:X}"
                    : $"Encountered unknown command 0x{command:X}";

                this.Log(LogLevel.Error, message);
                SendResponse(Response.FatalError(message));
                return false;
            }

            return true;
        }

        private void OnBytesWritten(byte[] data)
        {
            buffer.AddRange(data);
            this.Log(LogLevel.Noisy, "Received new data: {0}", Misc.PrettyPrintCollectionHex(data));
            this.Log(LogLevel.Debug, "Current buffer: {0}", Misc.PrettyPrintCollectionHex(buffer));

            switch(state)
            {
            case State.Handshake:
                if(buffer.Count < HandshakeHeaderSize)
                {
                    return;
                }
                commandsToActivate = BitConverter.ToUInt16(buffer.GetRange(0, HandshakeHeaderSize).ToArray(), 0);
                buffer.RemoveRange(0, HandshakeHeaderSize);
                this.Log(LogLevel.Noisy, "{0} commands to activate", commandsToActivate);

                state = State.WaitingForHandshakeData;
                goto case State.WaitingForHandshakeData;

            case State.WaitingForHandshakeData:
                if(commandsToActivate > 0 && buffer.Count >= 2)
                {
                    var toActivate = (int)Math.Min(commandsToActivate, buffer.Count / 2);

                    if(!TryActivateCommands(buffer.GetRange(0, toActivate * 2)))
                    {
                        socketServerProvider.Stop();
                        return;
                    }

                    buffer.RemoveRange(0, toActivate * 2);
                    commandsToActivate -= toActivate;
                }

                if(commandsToActivate > 0)
                {
                    return;
                }

                SendResponse(Response.SuccessfulHandshake());
                this.Log(LogLevel.Noisy, "Handshake finished");

                state = State.WaitingForHeader;
                goto case State.WaitingForHeader;

            case State.WaitingForHeader:
                if(buffer.Count < HeaderSize)
                {
                    return;
                }

                header = Packet.Decode<ExternalControlProtocolHeader>(buffer);
                if(!IsHeaderValid())
                {
                    var message = $"Encountered invalid header: {header}";
                    this.Log(LogLevel.Error, message);
                    SendResponse(Response.FatalError(message));
                    socketServerProvider.Stop();
                    return;
                }

                this.Log(LogLevel.Noisy, "Received header: {0}", header);
                buffer.RemoveRange(0, HeaderSize);

                state = State.WaitingForData;
                goto case State.WaitingForData;

            case State.WaitingForData:
                if(buffer.Count < header.Value.dataSize)
                {
                    return;
                }

                TryHandleCommand(out var response, header.Value.command, buffer.GetRange(0, (int)header.Value.dataSize));

                buffer.RemoveRange(0, (int)header.Value.dataSize);
                header = null;

                SendResponse(response);

                state = State.WaitingForHeader;
                goto case State.WaitingForHeader;

            case State.NotConnected:
            default:
                throw new Exception("Unreachable");
            }
        }

        private bool TryHandleCommand(out Response response, Command command, List<byte> data)
        {
            try
            {
                response = commandHandlers.Invoke(command, data);
                return true;
            }
            catch(RecoverableException e)
            {
                this.Log(LogLevel.Error, "{0} command error: {1}", command, e.Message);
                response = Response.CommandFailed(command, e.Message);
                return false;
            }
        }

        private void SendResponse(Response response)
        {
            var bytes = response.GetBytes();
            socketServerProvider.Send(bytes);
            this.Log(LogLevel.Debug, "Response sent: {0}", response);
            this.Log(LogLevel.Noisy, "Bytes sent: {0}", Misc.PrettyPrintCollectionHex(bytes));
        }

        private Response HandleRunFor(List<byte> data)
        {
            if(data.Count != 8)
            {
                return Response.CommandFailed(Command.RunFor, "Expected 8 bytes of payload");
            }

            var microseconds = BitConverter.ToUInt64(data.ToArray(), 0);
            var interval = TimeInterval.FromMicroseconds(microseconds);

            this.Log(LogLevel.Info, "Executing RunFor({0}) command", interval);
            emulation.RunFor(interval);

            return Response.Success(Command.RunFor);
        }

        private State state = State.NotConnected;
        private int commandsToActivate = 0;
        private ExternalControlProtocolHeader? header;

        private readonly List<byte> buffer = new List<byte>();
        private readonly Emulation emulation;
        private readonly CommandHandlerCollection commandHandlers;
        private readonly SocketServerProvider socketServerProvider = new SocketServerProvider(emitConfigBytes: false);

        private const int HeaderSize = 7;
        private const int HandshakeHeaderSize = 2;
        private const string Magic = "RE";

        [LeastSignificantByteFirst]
        private struct ExternalControlProtocolHeader
        {
            public override string ToString()
            {
                return $"{{ magic: {Misc.PrettyPrintCollectionHex(magic)} ({Encoding.ASCII.GetString(magic)}), command: 0x{(byte)command} ({command}), dataSize: {dataSize} }}";
            }

#pragma warning disable 649
            [PacketField, Width(2)]
            public byte[] magic;
            [PacketField, Width(8)]
            public Command command;
            [PacketField, Width(32)]
            public uint dataSize;
#pragma warning restore 649
        }

        private class Response
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

            private Response(ReturnCode returnCode)
                : this(returnCode, null, (byte[])null)
            {
            }

            private Response(ReturnCode returnCode, string text)
                : this(returnCode, null, text)
            {
            }

            private Response(ReturnCode returnCode, Command? command, string text)
                : this(returnCode, command, Encoding.ASCII.GetBytes(text))
            {
                dataIsText = true;
            }

            private Response(ReturnCode returnCode, Command? command, IEnumerable<byte> data)
                : this(returnCode, command, data.ToArray())
            {
            }

            private Response(ReturnCode returnCode, Command? command, byte[] data = null)
            {
                // Command can be null only for FatalError and SuccessfulHandshake
                DebugHelper.Assert(command != null || returnCode == ReturnCode.FatalError || returnCode == ReturnCode.SuccessfulHandshake);

                this.returnCode = returnCode;
                this.command = command;
                this.data = data;
                dataIsText = false;
            }

            public IEnumerable<byte> GetBytes()
            {
                var response = new List<byte> { (byte)returnCode };

                if(command.HasValue)
                {
                    response.Add((byte)command);
                }

                if(data != null && data.Any())
                {
                    response.AddRange(checked((uint)data.Length).AsRawBytes());
                    response.AddRange(data);
                }

                return response;
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

            private readonly bool dataIsText;
            private readonly Command? command;
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
            }
        }

        private class CommandHandlerCollection
        {
            public CommandHandlerCollection()
            {
                commandHandlers = new Dictionary<Command, Tuple<byte, Func<List<byte>, Response>>>();
                activeCommandHandlers = new Dictionary<Command, Func<List<byte>, Response>>();
            }

            public void Register(Command command, byte version, Func<List<byte>, Response> handler)
            {
                commandHandlers.Add(command, Tuple.Create(version, handler));
            }

            public void ClearActivation()
            {
                activeCommandHandlers.Clear();
            }

            public bool TryActivate(Command command, byte version)
            {
                if(activeCommandHandlers.ContainsKey(command))
                {
                    return false;
                }

                if(!commandHandlers.TryGetValue(command, out var tuple))
                {
                    return false;
                }

                if(tuple.Item1 != version)
                {
                    return false;
                }

                activeCommandHandlers.Add(command, tuple.Item2);
                return true;
            }

            public Response Invoke(Command command, List<byte> data)
            {
                if(!activeCommandHandlers.TryGetValue(command, out var handler))
                {
                    return Response.InvalidCommand(command);
                }
                return handler(data);
            }

            public bool TryGetVersion(Command command, out byte version)
            {
                if(!commandHandlers.TryGetValue(command, out var tuple))
                {
                    version = default(byte);
                    return false;
                }

                version = tuple.Item1;
                return true;
            }

            private readonly Dictionary<Command, Tuple<byte, Func<List<byte>, Response>>> commandHandlers;
            private readonly Dictionary<Command, Func<List<byte>, Response>> activeCommandHandlers;
        }

        private enum Command : byte
        {
            RunFor = 1,
        }

        private enum State
        {
            NotConnected,
            Handshake,
            WaitingForHandshakeData,
            WaitingForHeader,
            WaitingForData,
            Disposed,
        }
    }
}
