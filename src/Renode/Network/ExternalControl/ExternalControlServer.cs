//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
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
            commandHandlers.EventReported += SendEventResponse;
            commandHandlers.Register(new RunFor(this));
            commandHandlers.Register(new GetTime(this));
            commandHandlers.Register(new ADC(this));
            commandHandlers.Register(new GPIOPort(this));
            commandHandlers.Register(new SystemBus(this));

            var getMachineHandler = new GetMachine(this);
            Machines = getMachineHandler;
            commandHandlers.Register(getMachineHandler);

            socketServerProvider.ConnectionAccepted += delegate
            {
                lock(locker)
                {
                    if(state == State.Disposed)
                    {
                        return;
                    }
                    this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.Handshake);
                    state = State.Handshake;
                }
                this.Log(LogLevel.Debug, "Connection established");
            };
            socketServerProvider.ConnectionClosed += delegate
            {
                lock(locker)
                {
                    if(state == State.Disposed)
                    {
                        return;
                    }
                    commandHandlers.ClearActivation();
                    this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.NotConnected);
                    state = State.NotConnected;
                }
                this.Log(LogLevel.Debug, "Connection closed");
            };

            socketServerProvider.DataBlockReceived += OnBytesWritten;
            socketServerProvider.Start(port);

            this.Log(LogLevel.Info, "{0}: Listening on port {1}", nameof(ExternalControlServer), port);
        }

        public void Dispose()
        {
            lock(locker)
            {
                this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.Disposed);
                state = State.Disposed;
            }
            commandHandlers.Dispose();
            socketServerProvider.Stop();
        }

        public IMachineContainer Machines { get; }

        public bool EventsEnabled = false;

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

            if(header.Value.DataSize > (uint)Int32.MaxValue)
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

        private State? StepReceiveFiniteStateMachine(State currentState)
        {
            switch(currentState)
            {
            case State.Handshake:
                if(buffer.Count < HandshakeHeaderSize)
                {
                    return null;
                }
                commandsToActivate = BitConverter.ToUInt16(buffer.GetRange(0, HandshakeHeaderSize).ToArray(), 0);
                buffer.RemoveRange(0, HandshakeHeaderSize);
                this.Log(LogLevel.Noisy, "{0} commands to activate", commandsToActivate);

                return State.WaitingForHandshakeData;

            case State.WaitingForHandshakeData:
                if(commandsToActivate > 0 && buffer.Count >= 2)
                {
                    var toActivate = (int)Math.Min(commandsToActivate, buffer.Count / 2);

                    lock(locker)
                    {
                        AssertNotDisposed();
                        if(!TryActivateCommands(buffer.GetRange(0, toActivate * 2)))
                        {
                            socketServerProvider.Stop();
                            return null;
                        }
                    }

                    buffer.RemoveRange(0, toActivate * 2);
                    commandsToActivate -= toActivate;
                }

                if(commandsToActivate > 0)
                {
                    return null;
                }

                SendResponse(Response.SuccessfulHandshake());

                return State.WaitingForHeader;

            case State.WaitingForHeader:
                if(buffer.Count < HeaderSize)
                {
                    return null;
                }

                header = Packet.Decode<ExternalControlProtocolHeader>(buffer);
                if(!IsHeaderValid())
                {
                    var message = $"Encountered invalid header: {header}";
                    this.Log(LogLevel.Error, message);
                    lock(locker)
                    {
                        SendResponse(Response.FatalError(message));
                        socketServerProvider.Stop();
                    }
                    return null;
                }

                this.Log(LogLevel.Noisy, "Received header: {0}", header);
                buffer.RemoveRange(0, HeaderSize);

                return State.WaitingForData;

            case State.WaitingForData:
                if(buffer.Count < header.Value.DataSize)
                {
                    return null;
                }

                TryHandleCommand(out var response, header.Value.Command, buffer.GetRange(0, (int)header.Value.DataSize));

                buffer.RemoveRange(0, (int)header.Value.DataSize);
                header = null;

                SendResponse(response);

                return State.WaitingForHeader;

            case State.NotConnected:
            default:
                throw new Exception("Unreachable");
            }
        }

        private void OnBytesWritten(byte[] data)
        {
            buffer.AddRange(data);
            this.Log(LogLevel.Noisy, "Received new data: {0}", Misc.PrettyPrintCollectionHex(data));
            this.Log(LogLevel.Debug, "Current buffer: {0}", Misc.PrettyPrintCollectionHex(buffer));

            var lockedState = state;
            while(lockedState != State.Disposed && lockedState != State.NotConnected)
            {
                var nextState = (State?)null;
                try
                {
                    nextState = StepReceiveFiniteStateMachine(lockedState);
                }
                catch(ServerDisposedException)
                {
                    return;
                }

                lock(locker)
                {
                    if(!nextState.HasValue || state == State.Disposed || state == State.NotConnected)
                    {
                        return;
                    }
                    this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, nextState.Value);
                    state = nextState.Value;
                    lockedState = state;
                }
            }
        }

        private bool TryHandleCommand(out Response response, Command command, List<byte> data)
        {
            ICommand commandHandler;
            lock(locker)
            {
                AssertNotDisposed();
                commandHandler = commandHandlers.GetHandler(command);
            }

            if(commandHandler == null)
            {
                response = Response.InvalidCommand(command);
                return true;
            }

            try
            {
                // Create an ICanReportEvents interface or something similar if
                // we ever have more command handlers that need to do this.
                if(commandHandler is RunFor)
                {
                    EventsEnabled = true;
                }

                response = commandHandler.Invoke(data);
                return true;
            }
            catch(RecoverableException e)
            {
                this.Log(LogLevel.Error, "{0} command error: {1}", command, e.Message);
                response = Response.CommandFailed(command, e.Message);
                return false;
            }
            finally
            {
                if(commandHandler is RunFor)
                {
                    EventsEnabled = false;
                }
            }
        }

        private void SendEventResponse(Response response)
        {
            if(EventsEnabled)
            {
                SendResponse(response);
            }
        }

        private void SendResponse(Response response)
        {
            var bytes = response.GetBytes();
            lock(locker)
            {
                AssertNotDisposed();
                socketServerProvider.Send(bytes);
            }
            this.Log(LogLevel.Debug, "Response sent: {0}", response);
            this.Log(LogLevel.Noisy, "Bytes sent: {0}", Misc.PrettyPrintCollectionHex(bytes));
        }

        private void AssertNotDisposed()
        {
            if(state == State.Disposed)
            {
                throw new ServerDisposedException();
            }
        }

        private State state = State.NotConnected;
        private int commandsToActivate = 0;
        private ExternalControlProtocolHeader? header;

        private readonly List<byte> buffer = new List<byte>();
        private readonly CommandHandlerCollection commandHandlers;
        private readonly SocketServerProvider socketServerProvider = new SocketServerProvider(telnetMode: false);

        private readonly object locker = new object();

        private const int HeaderSize = 7;
        private const int HandshakeHeaderSize = 2;
        private const string Magic = "RE";

        private class CommandHandlerCollection : IDisposable
        {
            public CommandHandlerCollection()
            {
                commandHandlers = new Dictionary<Command, ICommand>();
                activeCommandHandlers = new Dictionary<Command, ICommand>();
            }

            public void Dispose()
            {
                activeCommandHandlers.Clear();
                foreach(var command in commandHandlers.Values.OfType<IDisposable>())
                {
                    command.Dispose();
                }
                commandHandlers.Clear();
            }

            public void Register(ICommand command)
            {
                commandHandlers.Add(command.Identifier, command);
                if(command is IHasEvents commandWithEvents)
                {
                    commandWithEvents.EventReported += this.EventReported;
                }
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

            public ICommand GetHandler(Command id)
            {
                if(!activeCommandHandlers.TryGetValue(id, out var command))
                {
                    return null; ;
                }
                return command;
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

            public event Action<Response> EventReported;

            private readonly Dictionary<Command, ICommand> commandHandlers;
            private readonly Dictionary<Command, ICommand> activeCommandHandlers;
        }

        private class ServerDisposedException : RecoverableException
        {
            public ServerDisposedException()
                : base()
            {
            }
        }

        [LeastSignificantByteFirst]
        private struct ExternalControlProtocolHeader
        {
            public override string ToString()
            {
                return $"{{ magic: {Misc.PrettyPrintCollectionHex(MagicField)} ({Magic}), command: 0x{(byte)Command} ({Command}), dataSize: {DataSize} }}";
            }

            public string Magic
            {
                get
                {
                    try
                    {
                        return Encoding.ASCII.GetString(MagicField);
                    }
                    catch
                    {
                        return "<invalid>";
                    }
                }
            }

#pragma warning disable 649
            [PacketField, Width(bytes: 2)]
            public byte[] MagicField;
            [PacketField, Width(8)]
            public Command Command;
            [PacketField, Width(32)]
            public uint DataSize;
#pragma warning restore 649
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