//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Peripherals.Plugins
{
    class OsTimeSkipHook
    {
        public static void Enable(ICPU cpu, string symbolHook, ulong usPerTick = 1)
        {
            OsSymbolHook.Enable(cpu, symbolHook, (ICpuSupportingGdb c, ulong address) =>
            {
                SkipTimeHook(c, address, usPerTick);
            });
        }

        private static void SkipTimeHook(ICpuSupportingGdb cpu, ulong address, ulong usPerTick)
        {
            var translationCpu = (TranslationCPU)cpu;

            if(!OsSymbolHook.TryGetReturnAddress(cpu, out var returnAddress))
            {
                Logger.Log(LogLevel.Warning, "Unable to get time skip return address");
                return;
            }

            if(!OsSymbolHook.TryGetFirstParameter(cpu, out var firstParameter))
            {
                Logger.Log(LogLevel.Warning, "Unable to get time skip first parameter");
                return;
            }

            var delayUs = firstParameter;
            var timeInterval = TimeInterval.FromMicroseconds(delayUs * usPerTick);

            translationCpu.SkipTime(timeInterval);

            translationCpu.Profiler?.StackFramePop(address, returnAddress, translationCpu.ExecutedInstructions);
            cpu.PC = returnAddress;
        }
    }
}