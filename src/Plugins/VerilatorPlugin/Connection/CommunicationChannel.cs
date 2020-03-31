//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class CommunicationChannel : IDisposable
    {
        public CommunicationChannel(IEmulationElement parentElement, int timeoutInMilliseconds)
        {
            logElement = parentElement;
            timeout = timeoutInMilliseconds;

            ListenerPort = CreateListenerAndStartListening();
        }

        public bool AcceptConnection(int timeoutInMilliseconds)
        {
            // Check if there's any connection waiting to be accepted (with timeout in MICROseconds)
            var acceptAttempt = listener.Poll(timeoutInMilliseconds * 1000, SelectMode.SelectRead);
            if(acceptAttempt)
            {
                socket = listener.Accept();
                socket.SendTimeout = timeout;
            }
            return acceptAttempt;
        }

        public void CloseListener()
        {
            listener.Close();
            listener = null;
        }

        public void ResetConnections()
        {
            socket?.Close();

            if(listener.Poll(0, SelectMode.SelectRead))
            {
                logElement.DebugLog($"Clients are pending on the listening {ListenerPort} port. Connection queue will be reset.");

                // There's no other way to reset listener's connection queue
                CloseListener();
                CreateListenerAndStartListening(ListenerPort);
            }
        }

        public bool TrySend(ProtocolMessage message)
        {
            var buffer = message.Serialize();
            return socket.Send(buffer) == buffer.Length;
        }

        public bool TryReceive(out ProtocolMessage message)
        {
            message = new ProtocolMessage();
            var size = System.Runtime.InteropServices.Marshal.SizeOf(typeof(ProtocolMessage));
            var buffer = new byte[size];
            var result = socket.Receive(buffer) == size;
            if(result)
            {
                message.Deserialize(buffer);
            }
            return result;
        }

        public string ReceiveString(int size)
        {
            var buffer = new byte[size];
            socket.Receive(buffer);
            return Encoding.ASCII.GetString(buffer);
        }

        public void Dispose()
        {
            socket.Dispose();
        }

        public bool Connected => socket.Connected;
        public readonly int ListenerPort;

        private int CreateListenerAndStartListening(int port = 0)
        {
            listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listener.Bind(new IPEndPoint(IPAddress.Parse(Address), port));

            listener.Listen(MaxPendingConnections);
            return (listener.LocalEndPoint as IPEndPoint).Port;
        }

        private Socket listener;
        private Socket socket;

        private readonly IEmulationElement logElement;
        private readonly int timeout;

        private const string Address = "127.0.0.1";
        private const int MaxPendingConnections = 1;
    }
}
