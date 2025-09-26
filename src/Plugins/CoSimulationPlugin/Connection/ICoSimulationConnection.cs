//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection
{
    public interface ICoSimulationConnection : IDisposable
    {
        void Connect();

        bool TrySendMessage(ProtocolMessage message);

        bool TryRespond(ProtocolMessage message);

        bool TryReceiveMessage(out ProtocolMessage message);

        void HandleMessage();

        void Abort();

        bool IsConnected { get; }

        string SimulationFilePath { set; }

        string Context { get; set; }
    }
}