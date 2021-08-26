//
// Copyright (c) 2010-2022 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public interface IVerilatorConnection : IDisposable, IHasOwnLife
    {
        bool TrySendMessage(ProtocolMessage message);
        bool TryReceiveMessage(out ProtocolMessage message);

        void Abort();
        string SimulationFilePath { set; }
    }
}
