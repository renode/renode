//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using NetMQ;
using NetMQ.Sockets;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class Socket
    {
        public Socket()
        {
            socket = new PairSocket();
            Port = socket.BindRandomPort(Address);
        }

        public void Send(ProtocolMessage message)
        {
            var buffer = message.Serialize();
            if(!socket.TrySendFrame(TimeSpan.FromSeconds(3), buffer))
            {
                EmulationManager.Instance.CurrentEmulation.PauseAll();
                Logger.Log(LogLevel.Error, "Verilated connection timeout");
            }
        }

        public virtual ProtocolMessage Receive()
        {
            var result = new ProtocolMessage();
            if(!socket.TryReceiveFrameBytes(TimeSpan.FromSeconds(3), out var buffer))
            {
                EmulationManager.Instance.CurrentEmulation.PauseAll();
                Logger.Log(LogLevel.Error, "Verilated connection timeout");
            }
            result.Deserialize(buffer);
            return result;
        }

        public void Disconnect()
        {
            socket.Unbind($"{Address}:{Port}");
            socket.Dispose();
        }

        public int Port { get; private set; }

        protected PairSocket socket;

        private const string Address = "tcp://*";
    }
}
