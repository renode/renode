//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;

namespace Antmicro.Renode.Peripherals.Plugins
{
    public static class ZephyrMode
    {
        public static void EnableZephyrMode(this ICPU cpu, params string[] disableIfSymbolsPresent)
        {
            foreach(var symbol in unsupportedSymbols)
            {
                if(!disableIfSymbolsPresent.Contains(symbol) && cpu.Bus.TryGetAllSymbolAddresses(symbol, out _, cpu))
                {
                    cpu.Log(LogLevel.Info, "Symbol '{0}' detected in the binary is known to affect the Zephyr Mode. You may want to disable it if you experience issues with `{1} {2} \"{0}\"`", symbol, cpu.GetMachine().GetLocalName(cpu), nameof(EnableZephyrMode));
                }
            }

            foreach(var symbol in disableIfSymbolsPresent)
            {
                if(cpu.Bus.TryGetAllSymbolAddresses(symbol, out _, cpu))
                {
                    cpu.Log(LogLevel.Warning, "ZephyrMode is disabled because the symbol '{0}' is present in the binary", symbol);
                    return;
                }
            }

            OsTimeSkipHook.Enable(cpu, "z_impl_k_busy_wait");
        }

        public static void DisableZephyrMode(this ICPU cpu)
        {
            OsSymbolHook.Disable(cpu, "z_impl_k_busy_wait");
        }

        private static readonly List<string> unsupportedSymbols = new List<string> {
            "CONFIG_TICKLESS_KERNEL",
        };
    }
}