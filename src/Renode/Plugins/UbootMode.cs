//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;

using ELFSharp.ELF;

namespace Antmicro.Renode.Peripherals.Plugins
{
    public static class UbootMode
    {
        public static void EnableUbootMode(this ICPU cpu)
        {
            OsTimeSkipHook.Enable(cpu, "udelay");
            OsSymbolHook.Enable(cpu, "relocate_code", RelocationHook);
        }

        public static void DisableUbootMode(this ICPU cpu)
        {
            OsSymbolHook.Disable(cpu, "udelay");
            OsSymbolHook.Disable(cpu, "relocate_code");
        }

        private static void RelocationHook(ICpuSupportingGdb cpu, ulong address)
        {
            var sysbus = cpu.GetMachine().SystemBus;
            if(!(sysbus is SystemBus))
            {
                Logger.Log(LogLevel.Warning, "Post-relocation symbol reloading failed. Wrong refrerence to sysbus");
                return;
            }
            if(!TryGetRelocAddr(cpu, out ulong relocaddr))
            {
                Logger.Log(LogLevel.Warning, "Post-relocation symbol reloading failed. Unable to get U-Boot relocation address");
                return;
            }
            try
            {
                ReloadSymbols((SystemBus)sysbus, relocaddr);
            }
            catch(System.OverflowException)
            {
                // Catching OverflowException to handle cases where SymbolLookup::LoadELF<uint> fails due to the text section address (relocAddr)
                // being greater than minLoadAddress. This is a workaround, and the downstream logic should be improved to allow for such cases.
                Logger.Log(LogLevel.Warning, "Post-relocation symbol reloading failed.");
                return;
            }
            Logger.Log(LogLevel.Info, "U-Boot relocated to 0x{0:X}", relocaddr);
        }

        private static void ReloadSymbols(SystemBus sysbus, ulong relocaddr)
        {
            var fingerprint = sysbus
                .GetLoadedFingerprints()
                .FirstOrDefault(f => ELFReader.CheckELFType(f.FileName) != Class.NotELF);
            if(fingerprint == default(BinaryFingerprint))
            {
                Logger.Log(LogLevel.Noisy, "Post-relocation symbol reloading failed. U-Boot ELF wasn't loaded.");
                return;
            }
            sysbus.LoadSymbolsFrom(fingerprint.FileName, textAddress: relocaddr);
        }

        private static bool TryGetRelocAddr(ICpuSupportingGdb cpu, out ulong relocaddr)
        {
            switch(cpu.Architecture)
            {
            case "arm-m":
            case "arm":
            // use r0
            // https://github.com/u-boot/u-boot/blob/636fcc96c3d7e2b00c843e6da78ed3e9e3bdf4de/arch/arm/lib/relocate.S#L68
            case "arm64":
                // use x0
                // https://github.com/u-boot/u-boot/blob/636fcc96c3d7e2b00c843e6da78ed3e9e3bdf4de/arch/arm/lib/relocate_64.S#L20
                relocaddr = cpu.GetRegister(0).RawValue; // x0/r0
                return true;
            case "riscv64":
            case "riscv32":
            case "riscv":
                // use a2
                // https://github.com/u-boot/u-boot/blob/636fcc96c3d7e2b00c843e6da78ed3e9e3bdf4de/arch/riscv/cpu/start.S#L286
                relocaddr = cpu.GetRegister(12).RawValue;
                return true;
            }
            relocaddr = 0;
            return false;
        }
    }
}