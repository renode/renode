//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Addons
{
    public static class RegistersMonitor
    {
        public static void TrackRegister(this BaseRiscV @this, int registerId)
        {
            @this.MaximumBlockSize = 1;

            var context = new Context { registerId = registerId, cpu = @this };
            @this.SetHookAtBlockBegin((pc, size) => HandleBlockBegin(pc, size, context));
        }

        private static void HandleBlockBegin(ulong pc, uint size, Context ctx)
        {
            // with MaximumBlockSize == 1 we should never get a bigger block
            DebugHelper.Assert(size <= 1);

            var val = ctx.cpu.GetRegisterUnsafe(ctx.registerId);
            if(!ctx.used || ctx.prevValue != val.RawValue)
            {
                ctx.prevValue = val.RawValue;
                ctx.cpu.Log(LogLevel.Info, "*** PC: 0x{0:X} register #{1} is now: 0x{2:X}", pc, ctx.registerId, val.RawValue);
            }
            ctx.used = true;
        }

        private class Context
        {
            public bool used;
            public int registerId;
            public ulong prevValue;
            public BaseRiscV cpu;
        }
    }
}
