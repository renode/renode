//
// Copyright (c) 2010-2025 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Time;
using Antmicro.Renode.Peripherals.Bus;
using System;
using System.Collections.Generic;
using Antmicro.Renode.Exceptions;
using System.Text;

namespace Antmicro.Renode.Peripherals.Plugins
{
    public static class ZephyrMode
    {
        public static void EnableZephyrMode(this ICPU cpu)
        {
            OsTimeSkipHook.Enable(cpu, "z_impl_k_busy_wait");
        }

        public static void DisableZephyrMode(this ICPU cpu)
        {
            OsSymbolHook.Disable(cpu, "z_impl_k_busy_wait");
        }
    }
}
