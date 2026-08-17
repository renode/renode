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
using System.Threading;

using Antmicro.Renode.Core;
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
            disposeCancelationTokenSource = new();

            externalHandler = new CommunicationHandler(true, this);
            internalHandler = new CommunicationHandler(false, this);
            defaultHandlerThread = new Thread(DefaultThreadHandlerBody)
            {
                Name = GetType().Name + "_DefaultHandlerThread",
                IsBackground = true
            };

            commandHandlers = new CommandHandlerCollection();
            commandHandlers.Register(new RunFor(this));
            commandHandlers.Register(new GetTime(this));
            commandHandlers.Register(new ADC(this));
            commandHandlers.Register(new GPIOPort(this));
            commandHandlers.Register(new SystemBus(this));
            commandHandlers.Register(new CheckVersion(this));

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

            defaultHandlerThread.Start(disposeCancelationTokenSource.Token);
        }

        public void Dispose()
        {
            lock(locker)
            {
                this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.Disposed);
                state = State.Disposed;
            }
            disposeCancelationTokenSource.Cancel();
            commandHandlers.Dispose();
            socketServerProvider.Stop();
            defaultHandlerThread.Join();
            disposeCancelationTokenSource.Dispose();
        }

        public ICommand GetCommandHandler(Command command)
        {
            return commandHandlers.GetHandler(command);
        }

        public MessagePayload SendRequest(MessagePayload request)
        {
            var handler = GetHandlerForCurrentThread();
            try
            {
                // External handler is used only by Default Thread Handler
                if(handler != externalHandler)
                {
                    Monitor.Enter(handler);
                }

                var response = handler.SendRequest(request, disposeCancelationTokenSource.Token);
                return response;
            }
            catch(OperationCanceledException)
            {
                throw new ServerDisposedException();
            }
            finally
            {
                if(handler != externalHandler)
                {
                    Monitor.Exit(handler);
                }
            }
        }

        public void SendMessage(Message message)
        {
            var bytes = message.ToBytes();
            lock(locker)
            {
                AssertNotDisposed();
                socketServerProvider.Send(bytes);
            }
            this.Log(LogLevel.Debug, "Message sent: {0}", message);
        }

        public IMachineContainer Machines { get; }

        private State? StepReceiveFiniteStateMachine(State currentState)
        {
            switch(currentState)
            {
            case State.WaitingForHeader:
                if(!Message.TryDecodeHeader(buffer, out currentMessage))
                {
                    return null;
                }

                this.Log(LogLevel.Noisy, "Received header: {0}", currentMessage);

                return State.WaitingForData;

            case State.WaitingForData:
                if(!currentMessage.TryDecodePayload(buffer))
                {
                    return null;
                }

                this.Log(LogLevel.Debug, "Message received: {0}", currentMessage);
                GetHandlerForMessage(currentMessage).PutMessage(currentMessage);

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

        private void AssertNotDisposed()
        {
            if(state == State.Disposed)
            {
                throw new ServerDisposedException();
            }
        }

        private void DefaultThreadHandlerBody(object obj)
        {
            var cancelationToken = (CancellationToken)obj;

            try
            {
                while(true)
                {
                    externalHandler.HandleRequestsUntilResponse(cancelationToken);
                }
            }
            catch(OperationCanceledException)
            {
                // It is expected to be thrown while disposing the server
            }
        }

        private CommunicationHandler GetHandlerForMessage(Message message) =>
            message.IsExternallyInitiated ? externalHandler : internalHandler;

        private CommunicationHandler GetHandlerForCurrentThread() =>
            defaultHandlerThread.ManagedThreadId == Environment.CurrentManagedThreadId ? externalHandler : internalHandler;

        private State state = State.NotConnected;
        private Message currentMessage;

        private readonly List<byte> buffer = new List<byte>();
        private readonly CommandHandlerCollection commandHandlers;
        private readonly SocketServerProvider socketServerProvider = new SocketServerProvider(telnetMode: false);
        private readonly Thread defaultHandlerThread;
        private readonly CommunicationHandler externalHandler;
        private readonly CommunicationHandler internalHandler;
        private readonly CancellationTokenSource disposeCancelationTokenSource;

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
            }

            public ICommand GetHandler(Command id)
            {
                if(!commandHandlers.TryGetValue(id, out var command))
                {
                    return null; ;
                }
                return command;
            }

            private readonly Dictionary<Command, ICommand> commandHandlers;
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
