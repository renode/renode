//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Network.ExternalControl;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Packets;

namespace Antmicro.Renode.Network
{
    public static class ExternalControlServerExtensions
    {
        public static void CreateExternalControlServer(this Emulation emulation, string name, int port)
        {
            emulation.ExternalsManager.AddExternal(new ExternalControlServer(port), name);
        }
    }

    public class ExternalControlServer : IDisposable, IExternal, IEmulationElement
    {
        public ExternalControlServer(int port)
        {
            socketServerProvider.BufferSize = 0x10;

            commandHandlers = new CommandHandlerCollection();
            commandHandlers.Register(new RunFor(this));

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

            if(header.Value.Magic != Magic)
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

        private State state = State.NotConnected;
        private int commandsToActivate = 0;
        private ExternalControlProtocolHeader? header;

        private readonly List<byte> buffer = new List<byte>();
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
                return $"{{ magic: {Misc.PrettyPrintCollectionHex(magic)} ({Magic}), command: 0x{(byte)command} ({command}), dataSize: {dataSize} }}";
            }

            public string Magic
            {
                get
                {
                    try
                    {
                        return Encoding.ASCII.GetString(magic);
                    }
                    catch
                    {
                        return "<invalid>";
                    }
                }
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

        private class CommandHandlerCollection
        {
            public CommandHandlerCollection()
            {
                commandHandlers = new Dictionary<Command, ICommand>();
                activeCommandHandlers = new Dictionary<Command, ICommand>();
            }

            public void Register(ICommand command)
            {
                commandHandlers.Add(command.Identifier, command);
            }

            public void ClearActivation()
            {
                activeCommandHandlers.Clear();
            }

            public bool TryActivate(Command id, byte version)
            {
                if(activeCommandHandlers.ContainsKey(id))
                {
                    return false;
                }

                if(!commandHandlers.TryGetValue(id, out var command))
                {
                    return false;
                }

                if(command.Version != version)
                {
                    return false;
                }

                activeCommandHandlers.Add(command.Identifier, command);
                return true;
            }

            public Response Invoke(Command id, List<byte> data)
            {
                if(!activeCommandHandlers.TryGetValue(id, out var command))
                {
                    return Response.InvalidCommand(id);
                }
                return command.Invoke(data);
            }

            public bool TryGetVersion(Command id, out byte version)
            {
                if(!commandHandlers.TryGetValue(id, out var command))
                {
                    version = default(byte);
                    return false;
                }

                version = command.Version;
                return true;
            }

            private readonly Dictionary<Command, ICommand> commandHandlers;
            private readonly Dictionary<Command, ICommand> activeCommandHandlers;
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
