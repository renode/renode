//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using NetMQ;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class ReceiverSocket : Socket
    {
        public string ReceiveString()
        {
            return socket.ReceiveFrameString();
        }

        public byte[] ReceiveBytes()
        {
            return socket.ReceiveFrameBytes();
        }

        public override ProtocolMessage Receive()
        {
            var result = new ProtocolMessage();
            result.Deserialize(socket.ReceiveFrameBytes());
            return result;
        }
    }
}
