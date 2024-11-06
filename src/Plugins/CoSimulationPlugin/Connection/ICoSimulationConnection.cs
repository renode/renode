//
// Copyright (c) 2010-2023 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection
{
    public interface ICoSimulationConnection : IDisposable, IHasOwnLife
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
