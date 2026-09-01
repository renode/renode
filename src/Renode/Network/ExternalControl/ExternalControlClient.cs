//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Exceptions;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class ExternalControlClient : ExternalControlSocket
    {
        public ExternalControlClient(int port) : base(port, isClient: true)
        {
            var response = SendRequest(MessagePayload.Request(Command.CheckVersion, CheckVersion.ProtocolVersion));
            if(!response.LogOnError(Command.CheckVersion, this))
            {
                Dispose();
                throw new RecoverableException("External control server version does not match the client version");
            }
        }
    }
}
