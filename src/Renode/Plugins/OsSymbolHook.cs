//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Hooks;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;

namespace Antmicro.Renode.Peripherals.Plugins
{
    public static class OsSymbolHook
    {
        public static bool TryGetReturnAddress(ICpuSupportingGdb cpu, out ulong returnAddress)
        {
            returnAddress = 0;
            switch(cpu.Architecture)
            {
            case "arm-m":
            case "arm":
                returnAddress = cpu.GetRegister(14).RawValue;
                return true;
            case "arm64":
                // RA register index in Renode for Arm differs between
                // the AArch64 (X30, index 30)  and AArch32 (R14, index 114) modes;
                // currently for Armv8R we support only the AArch32 mode
                // and for Armv8A we support only the AArch64 mode
                var regId = (cpu is ARMv8R) ? 114 : 30;
                returnAddress = cpu.GetRegister(regId).RawValue;
                return true;
            case "i386":
                // SystemV calling convention
                IMachine machine = cpu.GetMachine();
                returnAddress = ((SystemBus)machine.SystemBus).ReadDoubleWord(cpu.GetRegister(4).RawValue);
                return true;
            case "riscv64":
            case "riscv32":
            case "riscv":
                returnAddress = cpu.GetRegister(1).RawValue;
                return true;
            case "sparc":
                /*
                 * If subroutine uses SAVE instruction, then it's 15th register+8,
                 * if it doesn't use SAVE instruction, then it's 31th register+8.
                 * We can't easily detect it, it's dependent on how compiler will compile
                 * the function.
                 */
                returnAddress = cpu.GetRegister(15).RawValue + 8;
                return true;
            case "xtensa":
                returnAddress = cpu.GetRegister(89).RawValue;
                return true;
            }
            return false;
        }

        public static bool TryGetFirstParameter(ICpuSupportingGdb cpu, out ulong firstParameter)
        {
            firstParameter = 0;
            switch(cpu.Architecture)
            {
            case "arm-m":
            case "arm64":
            case "arm":
                firstParameter = cpu.GetRegister(0).RawValue;
                return true;
            case "i386":
                // SystemV calling convention
                IMachine machine = cpu.GetMachine();
                firstParameter = ((SystemBus)machine.SystemBus).ReadDoubleWord(cpu.GetRegister(4).RawValue + 4);
                return true;
            case "riscv64":
            case "riscv32":
            case "riscv":
                firstParameter = cpu.GetRegister(10).RawValue;
                return true;
            case "sparc":
                firstParameter = cpu.GetRegister(8).RawValue;
                return true;
            case "xtensa":
                /*
                 * Zephyr calls k_busy_wait with CALL8 instruction, first argument is in A10 register
                 */
                firstParameter = cpu.GetRegister(99).RawValue;
                return true;
            }
            return false;
        }

        public static void Enable(ICPU cpu, string hookSymbol, Action<ICpuSupportingGdb, ulong> hook)
        {
            IMachine machine = cpu.GetMachine();
            if(!(cpu is TranslationCPU) || !(machine.SystemBus is SystemBus))
            {
                throw new RecoverableException("This CPU doesn't support OS Time Skip Mode");
            }
            Disable(cpu, hookSymbol);
            Action<IMachine> configureSymbolsHooksWrapper = (IMachine localMachine) => ConfigureHook((ICPUWithHooks)cpu, localMachine, hookSymbol, hook, true);
            machine.SystemBus.OnSymbolsChanged += configureSymbolsHooksWrapper;
            enabledSymbolChecks.Add(Tuple.Create(cpu, hookSymbol), configureSymbolsHooksWrapper);
            ConfigureHook((ICPUWithHooks)cpu, machine, hookSymbol, hook, true);
        }

        public static void Disable(ICPU cpu, string hookSymbol)
        {
            var key = Tuple.Create(cpu, hookSymbol);
            if(enabledSymbolChecks.TryGetValue(key, out var configureSymbolsHooksWrapper))
            {
                IMachine machine = cpu.GetMachine();
                machine.SystemBus.OnSymbolsChanged -= configureSymbolsHooksWrapper;
                enabledSymbolChecks.Remove(key);
                ConfigureHook((ICPUWithHooks)cpu, machine, hookSymbol, null, false);
            }
        }

        public static void AddSymbolHook(this ICpuSupportingGdb cpu, string hookSymbol, string pythonScript)
        {
            var engine = new BlockPythonEngine(cpu.GetMachine(), cpu, pythonScript);
            Enable(cpu, hookSymbol, engine.Hook);
        }

        private static void ConfigureHook(ICPUWithHooks cpu, IMachine machine, string hookName, Action<ICpuSupportingGdb, ulong> hook, bool enableHook)
        {
            bool foundAddresses = ((SystemBus)machine.SystemBus).TryGetAllSymbolAddresses(hookName, out var addresses);
            if(!foundAddresses)
            {
                return;
            }
            Logger.Log(LogLevel.Noisy, "Trying to {0} hook on: {1}, number of hooks: {2}", enableHook ? "add" : "remove", hookName, addresses.Count());

            foreach(var address in addresses)
            {
                if(enableHook)
                {
                    cpu.AddHook(address, hook);
                }
                else
                {
                    cpu.RemoveHooksAt(address);
                }
            }
        }

        private static readonly Dictionary<Tuple<ICPU, string>, Action<IMachine>> enabledSymbolChecks = new Dictionary<Tuple<ICPU, string>, Action<IMachine>>();
    }
}