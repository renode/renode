//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using System.Net;
using PacketDotNet;

namespace Antmicro.Renode.Network
{
    public interface IServerModule
    {
    }

    public interface IUdpServerModule : IServerModule
    {
        void HandleUdp(IPEndPoint source, UdpPacket packet,
            Action<IPEndPoint, UdpPacket> callback);
    }
}