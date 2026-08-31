//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Network.ExternalControl;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network
{
    public static class ExternalControlServerExtensions
    {
        public static void CreateExternalControlServer(this Emulation emulation, string name, int port)
        {
            emulation.ExternalsManager.AddExternal(new ExternalControlSocket(port), name);
        }
    }

    public class ExternalControlSocket : IDisposable, IExternal, IEmulationElement
    {
        public ExternalControlSocket(int port)
        {
            this.port = port;
            RestartConnection();
        }

        public void Dispose()
        {
            Disconnect(State.Disposed);
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
                if(state != State.Active)
                {
                    throw new ServerDisposedException();
                }

                communicationSocket.Send(bytes.ToArray());
            }
            this.Log(LogLevel.Debug, "Message sent: {0}", message);
        }

        public IMachineContainer Machines { get; private set; }

        private void InitializeHandlers()
        {
            lock(locker)
            {
                this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, State.Active);
                state = State.Active;

                commandHandlers = new CommandHandlerCollection();
                commandHandlers.Register(new TimeElapsedCallbackCommand(this));
                commandHandlers.Register(new RunFor(this));
                commandHandlers.Register(new GetTime(this));
                commandHandlers.Register(new SPI(this));
                commandHandlers.Register(new ADC(this));
                commandHandlers.Register(new GPIOPort(this));
                commandHandlers.Register(new SystemBus(this));
                commandHandlers.Register(new CheckVersion(this));
                commandHandlers.Register(new CANBus(this));

                var getMachineHandler = new GetMachine(this);
                Machines = getMachineHandler;

                commandHandlers.Register(getMachineHandler);
                disposeCancelationTokenSource = new();

                externalHandler = new CommunicationHandler(isExternal: true, this);
                internalHandler = new CommunicationHandler(isExternal: false, this);
                defaultHandlerThread = new Thread(DefaultThreadHandlerBody)
                {
                    Name = GetType().Name + "_DefaultHandlerThread",
                    IsBackground = true
                };
                defaultHandlerThread.Start(disposeCancelationTokenSource.Token);
            }
        }

        private void DisposeHandlers()
        {
            lock(locker)
            {
                disposeCancelationTokenSource?.Cancel();
                defaultHandlerThread?.Join();
                internalHandler = null;
                externalHandler = null;

                commandHandlers?.Dispose();
                commandHandlers = null;

                disposeCancelationTokenSource?.Dispose();
            }
        }

        private void RestartConnection()
        {
            DebugHelper.Assert(communicationSocket == null);

            communicationSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            communicationSocket.NoDelay = true;

            try
            {
                communicationSocket.Bind(new IPEndPoint(IPAddress.Any, port));
                communicationSocket.Listen(backlog: 1);
            }
            catch(SocketException e)
            {
                throw new RecoverableException(e);
            }

            rxThread = new Thread(RxThreadBody)
            {
                Name = GetType().Name + "_RxHandler",
                IsBackground = true
            };
            rxThread.Start();
        }

        private void Disconnect(State newState)
        {
            State lastState;
            lock(locker)
            {
                lastState = state;
                this.Log(LogLevel.Noisy, "State change: {0} -> {1}", state, newState);
                state = newState;
            }

            CloseSocket(communicationSocket);

            if(rxThread?.ManagedThreadId != Thread.CurrentThread.ManagedThreadId)
            {
                rxThread?.Join();
            }
            rxThread = null;
            communicationSocket = null;

            if(lastState == State.Active)
            {
                DisposeHandlers();
            }

            if(newState == State.Unconnected)
            {
                RestartConnection();
            }
        }

        private void DefaultThreadHandlerBody(object obj)
        {
            var cancelationToken = (CancellationToken)obj;

            try
            {
                var handler = GetHandlerForCurrentThread();
                while(true)
                {
                    handler.HandleRequestsUntilResponse(cancelationToken);
                }
            }
            catch(OperationCanceledException)
            {
                this.Log(LogLevel.Debug, "Default thread handler has been canceled, it is expected while disposing {0}", nameof(ExternalControlSocket));
            }
        }

        private void RxThreadBody()
        {
            this.Log(LogLevel.Info, "Listening for connections on port: {0}", port);
            Socket finalSocket;
            try
            {
                finalSocket = communicationSocket.Accept();
            }
            catch(SocketException)
            {
                CloseSocket(communicationSocket);
                return;
            }

            CloseSocket(communicationSocket);
            communicationSocket = finalSocket;
            communicationSocket.NoDelay = true;
            this.Log(LogLevel.Info, "Connection accepted");

            InitializeHandlers();

            while(true)
            {
                try
                {
                    Span<byte> headerBuffer = stackalloc byte[Message.HeaderSize];
                    ReceiveAll(communicationSocket, headerBuffer);
                    if(!Message.TryDecodeHeader(headerBuffer, out var message))
                    {
                        this.ErrorLog("Invalid message header received: {0}", headerBuffer.ToArray().ToLazyHexString());
                        continue;
                    }
                    this.NoisyLog("Received header: {0}", message);

                    var payloadBuffer = new byte[message.PayloadSize];
                    ReceiveAll(communicationSocket, payloadBuffer);

                    if(!message.TryDecodePayload(payloadBuffer))
                    {
                        this.ErrorLog("Invalid message payload: {0}", payloadBuffer.ToLazyHexString());
                    }

                    this.DebugLog("Message received: {0}", message);
                    GetHandlerForMessage(message).PutMessage(message);
                }
                catch(OperationCanceledException)
                {
                    // Expected when terminating the connection
                    Disconnect(State.Unconnected);
                    return;
                }
                catch(SocketException e)
                {
                    this.ErrorLog("Socket error: {0}, disposing of the {1}", e.Message, "server");
                    Dispose();
                    return;
                }
            }
        }

        private void ReceiveAll(Socket sock, Span<byte> buffer)
        {
            var total = 0;
            while(total < buffer.Length)
            {
                var current = sock.Receive(buffer[total..]);
                if(current == 0)
                {
                    throw new OperationCanceledException();
                }
                total += current;
            }
        }

        private void CloseSocket(Socket sock)
        {
            if(sock == null)
            {
                return;
            }

            try
            {
                if(sock.Connected)
                {
                    sock.Shutdown(SocketShutdown.Both);
                }
            }
            finally
            {
                sock.Close();
            }
            sock.Dispose();
        }

        private CommunicationHandler GetHandlerForMessage(Message message) =>
            message.IsExternallyInitiated ? externalHandler : internalHandler;

        private CommunicationHandler GetHandlerForCurrentThread()
        {
            return defaultHandlerThread.ManagedThreadId == Environment.CurrentManagedThreadId ? externalHandler : internalHandler;
        }

        private State state = State.Unconnected;
        private Socket communicationSocket;
        private Thread rxThread;
        private Thread defaultHandlerThread;
        private CommunicationHandler externalHandler;
        private CommunicationHandler internalHandler;
        private CancellationTokenSource disposeCancelationTokenSource;
        private CommandHandlerCollection commandHandlers;

        private readonly int port;
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
            Unconnected,
            Active,
            Disposed,
        }
    }
}
