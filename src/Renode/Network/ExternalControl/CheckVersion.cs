//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class CheckVersion : BaseCommand
    {
        public CheckVersion(ExternalControlServer server)
            : base(server)
        {
        }

        public override MessagePayload Invoke(List<byte> data)
        {
            if(data.Count != sizeof(uint))
            {
                return MessagePayload.Error(Identifier, $"Expected at least {sizeof(uint)} bytes of data, but got {data.Count}");
            }

            var clientVersion = BitConverter.ToUInt32(CollectionsMarshal.AsSpan(data));

            if(clientVersion == ProtocolVersion)
            {
                return MessagePayload.Success(Identifier);
            }
            return MessagePayload.Error(Identifier, $"Version missmatch, client version: {clientVersion}, server version: {ProtocolVersion}");
        }

        public override Command Identifier => Command.CheckVersion;

        // Needs to be in sync with `PROTOCOL_VERSION` in C
        public const uint ProtocolVersion = 0;
    }
}
