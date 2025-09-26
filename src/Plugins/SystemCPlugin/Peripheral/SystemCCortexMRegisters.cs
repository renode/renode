//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

using Antmicro.Renode.Peripherals.CPU;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public partial class SystemCCortexMCPU
    {
        [Register]
        public RegisterValue Control
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.Control);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.Control, value);
            }
        }

        [Register]
        public RegisterValue BasePri
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.BasePri);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.BasePri, value);
            }
        }

        [Register]
        public RegisterValue VecBase
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.VecBase);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.VecBase, value);
            }
        }

        [Register]
        public RegisterValue CurrentSP
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.CurrentSP);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.CurrentSP, value);
            }
        }

        [Register]
        public RegisterValue OtherSP
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.OtherSP);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.OtherSP, value);
            }
        }

        [Register]
        public RegisterValue FPCCR
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.FPCCR);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.FPCCR, value);
            }
        }

        [Register]
        public RegisterValue FPCAR
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.FPCAR);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.FPCAR, value);
            }
        }

        [Register]
        public RegisterValue FPDSCR
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.FPDSCR);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.FPDSCR, value);
            }
        }

        [Register]
        public RegisterValue CPACR
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.CPACR);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.CPACR, value);
            }
        }

        [Register]
        public RegisterValue PRIMASK
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.PRIMASK);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.PRIMASK, value);
            }
        }

        [Register]
        public RegisterValue FAULTMASK
        {
            get
            {
                return GetRegisterValue32((int)SystemCCortexMRegisters.FAULTMASK);
            }

            set
            {
                SetRegisterValue32((int)SystemCCortexMRegisters.FAULTMASK, value);
            }
        }

        private static readonly Dictionary<SystemCCortexMRegisters, CPURegister> mapping = new Dictionary<SystemCCortexMRegisters, CPURegister>
        {
            { SystemCCortexMRegisters.R0,  new CPURegister(0, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R0" }) },
            { SystemCCortexMRegisters.R1,  new CPURegister(1, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R1" }) },
            { SystemCCortexMRegisters.R2,  new CPURegister(2, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R2" }) },
            { SystemCCortexMRegisters.R3,  new CPURegister(3, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R3" }) },
            { SystemCCortexMRegisters.R4,  new CPURegister(4, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R4" }) },
            { SystemCCortexMRegisters.R5,  new CPURegister(5, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R5" }) },
            { SystemCCortexMRegisters.R6,  new CPURegister(6, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R6" }) },
            { SystemCCortexMRegisters.R7,  new CPURegister(7, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R7" }) },
            { SystemCCortexMRegisters.R8,  new CPURegister(8, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R8" }) },
            { SystemCCortexMRegisters.R9,  new CPURegister(9, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R9" }) },
            { SystemCCortexMRegisters.R10,  new CPURegister(10, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R10" }) },
            { SystemCCortexMRegisters.R11,  new CPURegister(11, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R11" }) },
            { SystemCCortexMRegisters.R12,  new CPURegister(12, 32, isGeneral: true, isReadonly: false, aliases: new [] { "R12" }) },
            { SystemCCortexMRegisters.SP,  new CPURegister(13, 32, isGeneral: true, isReadonly: false, aliases: new [] { "SP", "R13" }) },
            { SystemCCortexMRegisters.LR,  new CPURegister(14, 32, isGeneral: true, isReadonly: false, aliases: new [] { "LR", "R14" }) },
            { SystemCCortexMRegisters.PC,  new CPURegister(15, 32, isGeneral: true, isReadonly: false, aliases: new [] { "PC", "R15" }) },
            { SystemCCortexMRegisters.Control,  new CPURegister(18, 32, isGeneral: false, isReadonly: false, aliases: new [] { "Control" }) },
            { SystemCCortexMRegisters.BasePri,  new CPURegister(19, 32, isGeneral: false, isReadonly: false, aliases: new [] { "BasePri" }) },
            { SystemCCortexMRegisters.VecBase,  new CPURegister(20, 32, isGeneral: false, isReadonly: false, aliases: new [] { "VecBase" }) },
            { SystemCCortexMRegisters.CurrentSP,  new CPURegister(21, 32, isGeneral: false, isReadonly: false, aliases: new [] { "CurrentSP" }) },
            { SystemCCortexMRegisters.OtherSP,  new CPURegister(22, 32, isGeneral: false, isReadonly: false, aliases: new [] { "OtherSP" }) },
            { SystemCCortexMRegisters.FPCCR,  new CPURegister(23, 32, isGeneral: false, isReadonly: false, aliases: new [] { "FPCCR" }) },
            { SystemCCortexMRegisters.FPCAR,  new CPURegister(24, 32, isGeneral: false, isReadonly: false, aliases: new [] { "FPCAR" }) },
            { SystemCCortexMRegisters.CPSR,  new CPURegister(25, 32, isGeneral: false, isReadonly: false, aliases: new [] { "CPSR" }) },
            { SystemCCortexMRegisters.FPDSCR,  new CPURegister(26, 32, isGeneral: false, isReadonly: false, aliases: new [] { "FPDSCR" }) },
            { SystemCCortexMRegisters.CPACR,  new CPURegister(27, 32, isGeneral: false, isReadonly: false, aliases: new [] { "CPACR" }) },
            { SystemCCortexMRegisters.PRIMASK,  new CPURegister(28, 32, isGeneral: false, isReadonly: false, aliases: new [] { "PRIMASK" }) },
            { SystemCCortexMRegisters.FAULTMASK,  new CPURegister(30, 32, isGeneral: false, isReadonly: false, aliases: new [] { "FAULTMASK" }) },
        };
    }

    public enum SystemCCortexMRegisters
    {
        SP = 13,
        LR = 14,
        PC = 15,
        CPSR = 25,
        Control = 18,
        BasePri = 19,
        VecBase = 20,
        CurrentSP = 21,
        OtherSP = 22,
        FPCCR = 23,
        FPCAR = 24,
        FPDSCR = 26,
        CPACR = 27,
        PRIMASK = 28,
        FAULTMASK = 30,
        R0 = 0,
        R1 = 1,
        R2 = 2,
        R3 = 3,
        R4 = 4,
        R5 = 5,
        R6 = 6,
        R7 = 7,
        R8 = 8,
        R9 = 9,
        R10 = 10,
        R11 = 11,
        R12 = 12,
        R13 = 13,
        R14 = 14,
        R15 = 15,
    }
}