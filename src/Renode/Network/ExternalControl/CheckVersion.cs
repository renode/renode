//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class CheckVersion : BaseCommand
    {
        public CheckVersion(ExternalControlSocket parent)
            : base(parent)
        {
        }

        public override MessagePayload Invoke(MessagePayload payload)
        {
            var data = payload.Data;
            if(data.Length != sizeof(uint))
            {
                return MessagePayload.Error(Identifier, $"Expected at least {sizeof(uint)} bytes of data, but got {data.Length}");
            }

            var clientVersion = BitConverter.ToUInt32(data);

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
