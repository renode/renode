//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;

using ELFSharp.ELF;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public partial class SystemCCortexMCPU : SystemCCPU
    {
        public SystemCCortexMCPU(IMachine machine, string address, int port, string cpuType, Endianess endianess = Endianess.LittleEndian, CpuBitness bitness = CpuBitness.Bits32, int timeSyncPeriodUS = 1000, bool disableTimeoutCheck = false)
            : base(machine, address, port, cpuType, endianess, bitness, timeSyncPeriodUS, disableTimeoutCheck)
        {
            // Intentionally left blank
        }

        [Register]
        public override RegisterValue PC
        {
            get => GetRegisterValue32((int)SystemCCortexMRegisters.PC);
            set => SetRegisterValue32((int)SystemCCortexMRegisters.PC, value);
        }

        [Register]
        public RegisterValue SP
        {
            get => GetRegisterValue32((int)SystemCCortexMRegisters.SP);
            set => SetRegisterValue32((int)SystemCCortexMRegisters.SP, value);
        }

        public override string Architecture { get { return "arm-m"; } }
    }
}