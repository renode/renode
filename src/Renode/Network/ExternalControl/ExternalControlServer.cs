//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Network.ExternalControl;
using Antmicro.Renode.Utilities;

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
                    this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.WaitingForHeader);
                    state = State.WaitingForHeader;
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

        private State? StepReceiveFiniteStateMachine(State currentState)
        {
            switch(currentState)
            {
            case State.WaitingForHeader:
                if(buffer.Count < Message.HeaderSize)
                {
                    return null;
                }

                if(!Message.TryDecodeHeader(buffer, out var tempHeader))
                {
                    var message = $"Encountered invalid communication header: {buffer.Take(Message.HeaderSize).ToLazyHexString()}";
                    this.ErrorLog(message);
                    lock(locker)
                    {
                        SendResponse(MessagePayload.Error(message));
                        socketServerProvider.Stop();
                    }
                    return null;
                }
                header = tempHeader;

                this.Log(LogLevel.Noisy, "Received header: {0}", header);
                buffer.RemoveRange(0, Message.HeaderSize);

                return State.WaitingForData;

            case State.WaitingForData:
                if(buffer.Count < header.Value.DataSize)
                {
                    return null;
                }

                header = header.Value.WithData(buffer);
                buffer.RemoveRange(0, (int)header.Value.DataSize);

                if(!MessagePayload.TryDecode(header.Value, out var commandHeader))
                {
                    var message = $"Encountered invalid command data header: {header.Value.Data.Take(MessagePayload.HeaderSize).ToLazyHexString()}";
                    this.ErrorLog(message);
                    lock(locker)
                    {
                        SendResponse(MessagePayload.Error(message));
                        socketServerProvider.Stop();
                    }
                    return null;
                }

                TryHandleCommand(out var response, (Command)commandHeader.Command, new List<byte>(commandHeader.Data));

                SendResponse(response);
                header = null;

                return State.WaitingForHeader;

            case State.NotConnected:
            default:
                throw new UnreachableException();
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

        private bool TryHandleCommand(out MessagePayload response, Command command, List<byte> data)
        {
            ICommand commandHandler;
            lock(locker)
            {
                AssertNotDisposed();
                commandHandler = commandHandlers.GetHandler(command);
            }

            if(commandHandler == null)
            {
                response = MessagePayload.InvalidCommand(command);
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
                response = MessagePayload.Error(command, e.Message);
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

        private void SendEventResponse(MessagePayload response)
        {
            if(EventsEnabled)
            {
                SendResponse(response);
            }
        }

        private void SendResponse(MessagePayload response)
        {
            var clientId = header?.ID ?? 0; // Fallback to 0 if a valid header has not been established yet
            var message = Message.ClientInitiated(clientId, response.ToBytes());
            var bytes = message.ToBytes();
            lock(locker)
            {
                AssertNotDisposed();
                socketServerProvider.Send(bytes);
            }
            this.Log(LogLevel.Debug, "Response sent: {0}", message);
            this.Log(LogLevel.Noisy, "Bytes sent: {0}", bytes.ToLazyHexString());
        }

        private void AssertNotDisposed()
        {
            if(state == State.Disposed)
            {
                throw new ServerDisposedException();
            }
        }

        private State state = State.NotConnected;
        private Message? header;

        private readonly List<byte> buffer = new List<byte>();
        private readonly CommandHandlerCollection commandHandlers;
        private readonly SocketServerProvider socketServerProvider = new SocketServerProvider(telnetMode: false);

        private readonly object locker = new object();

        private class CommandHandlerCollection : IDisposable
        {
            public CommandHandlerCollection()
            {
                commandHandlers = new Dictionary<Command, ICommand>();
            }

            public void Dispose()
            {
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

            public ICommand GetHandler(Command id)
            {
                if(!commandHandlers.TryGetValue(id, out var command))
                {
                    return null; ;
                }
                return command;
            }

            public event Action<MessagePayload> EventReported;

            private readonly Dictionary<Command, ICommand> commandHandlers;
        }

        private class ServerDisposedException : RecoverableException
        {
            public ServerDisposedException()
                : base()
            {
            }
        }

        private enum State
        {
            NotConnected,
            WaitingForHeader,
            WaitingForData,
            Disposed,
        }
    }
}
