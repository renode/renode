//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Peripherals.CPU;

namespace Antmicro.Renode.Peripherals.Plugins
{
    public static class TimeSkip
    {
        public static void EnableTimeSkip(this ICPU cpu, string symbol, ulong usPerTick = 1)
        {
            OsTimeSkipHook.Enable(cpu, symbol, usPerTick);
        }

        public static void DisableTimeSkip(this ICPU cpu, string symbol)
        {
            OsSymbolHook.Disable(cpu, symbol);
        }
    }
}