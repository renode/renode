//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class RunFor : BaseCommand
    {
        public RunFor(ExternalControlServer parent)
            : base(parent)
        {
        }

        public override MessagePayload Invoke(List<byte> data)
        {
            if(data.Count != 8)
            {
                return MessagePayload.Error(Identifier, "Expected 8 bytes of payload");
            }

            var nanoseconds = BitConverter.ToUInt64(CollectionsMarshal.AsSpan(data));
            var interval = TimeInterval.FromNanoseconds(nanoseconds);

            parent.Log(LogLevel.Info, "Executing RunFor({0}) command", interval);
            EmulationManager.Instance.CurrentEmulation.RunFor(interval);

            return MessagePayload.Success(Identifier);
        }

        public override Command Identifier => Command.RunFor;
    }
}
