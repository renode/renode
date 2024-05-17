//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class RunFor : BaseCommand
    {
        public RunFor(IEmulationElement parent)
            : base(parent)
        {
        }

        public override Response Invoke(List<byte> data)
        {
            if(data.Count != 8)
            {
                return Response.CommandFailed(Command.RunFor, "Expected 8 bytes of payload");
            }

            var microseconds = BitConverter.ToUInt64(data.ToArray(), 0);
            var interval = TimeInterval.FromMicroseconds(microseconds);

            parent.Log(LogLevel.Info, "Executing RunFor({0}) command", interval);
            EmulationManager.Instance.CurrentEmulation.RunFor(interval);

            return Response.Success(Command.RunFor);
        }

        public override Command Identifier => Command.RunFor;
        public override byte Version => 0x0;
    }
}
