//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class GetTime : BaseCommand
    {
        public GetTime(ExternalControlServer parent)
            : base(parent)
        {
        }

        public override Response Invoke(List<byte> data)
        {
            var timestamp = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime;
            parent.Log(LogLevel.Info, "Executing GetTime command: {0}", timestamp);

            return Response.Success(Identifier, ((ulong)timestamp.TotalMicroseconds).AsRawBytes());
        }

        public override Command Identifier => Command.GetTime;

        public override byte Version => 0x0;
    }
}