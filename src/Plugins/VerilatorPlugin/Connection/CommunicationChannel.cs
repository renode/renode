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

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class CommunicationChannel : IDisposable
    {
        public CommunicationChannel(int timeoutInMiliseconds)
        {
            listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listener.Bind(new IPEndPoint(IPAddress.Parse(Address), 0));
            Port = ((IPEndPoint)listener.LocalEndPoint).Port;
            listener.Listen(MaxPendingConnections);
            timeout = timeoutInMiliseconds;
        }

        public void AcceptConnection()
        {
            socket = listener.Accept();
            socket.SendTimeout = timeout;
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

        public int Port { get; private set; }

        protected Socket socket;
        private readonly Socket listener;
        private readonly int timeout;

        private const string Address = "127.0.0.1";
        private const int MaxPendingConnections = 1;
    }
}
