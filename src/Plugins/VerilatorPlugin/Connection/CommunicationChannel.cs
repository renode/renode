//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using NetMQ;
using NetMQ.Sockets;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class CommunicationChannel : IDisposable
    {
        public CommunicationChannel(double timeoutInSeconds)
        {
            socket = new PairSocket();
            Port = socket.BindRandomPort(AddressOffset);
            timeout = timeoutInSeconds;
        }

        public bool TrySend(ProtocolMessage message)
        {
            var buffer = message.Serialize();
            return socket.TrySendFrame(TimeSpan.FromSeconds(timeout), buffer);
        }

        public bool TryReceive(out ProtocolMessage message)
        {
            message = new ProtocolMessage();
            var result = socket.TryReceiveFrameBytes(TimeSpan.FromSeconds(timeout), out var buffer);
            if(result)
            {
                message.Deserialize(buffer);
            }
            return result;
        }

        public string ReceiveString()
        {
            return socket.ReceiveFrameString();
        }

        public void Dispose()
        {
            socket.Dispose();
        }

        public int Port { get; private set; }

        protected readonly PairSocket socket;
        private double timeout;
        private const string AddressOffset = "tcp://*";
    }
}
