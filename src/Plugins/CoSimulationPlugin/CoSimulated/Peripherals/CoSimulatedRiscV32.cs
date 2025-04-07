//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;

using ELFSharp.ELF;

using Machine = Antmicro.Renode.Core.Machine;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public partial class CoSimulatedRiscV32 : CoSimulatedCPU, ICpuSupportingGdb
    {
        public CoSimulatedRiscV32(string cpuType, Machine machine, Endianess endianness = Endianess.LittleEndian,
        CpuBitness bitness = CpuBitness.Bits32, string address = null)
            : base(cpuType, machine, endianness, bitness, address)
        {
        }

        public void SetRegister(int register, RegisterValue value)
        {
            if(!mapping.TryGetValue((CoSimulatedRiscV32Registers)register, out var r))
            {
                throw new RecoverableException($"Wrong register index: {register}");
            }
            if(r.IsReadonly)
            {
                throw new RecoverableException($"Register: {register} value is not writable.");
            }

            SetRegisterValue32(r.Index, checked((UInt32)value));
        }

        public void SetRegisterUnsafe(int register, RegisterValue value)
        {
            SetRegister(register, value);
        }

        public RegisterValue GetRegister(int register)
        {
            if(!mapping.TryGetValue((CoSimulatedRiscV32Registers)register, out var r))
            {
                throw new RecoverableException($"Wrong register index: {register}");
            }
            return GetRegisterValue32(r.Index);
        }

        public RegisterValue GetRegisterUnsafe(int register)
        {
            return GetRegister(register);
        }

        public IEnumerable<CPURegister> GetRegisters()
        {
            return mapping.Values.OrderBy(x => x.Index);
        }

        public void EnterSingleStepModeSafely(HaltArguments args)
        {
            // this method should only be called from CPU thread,
            // but we should check it anyway
            CheckCpuThreadId();

            ExecutionMode = ExecutionMode.SingleStep;

            UpdateHaltedState();
            InvokeHalted(args);
        }

        public void AddHookAtInterruptBegin(Action<ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtInterruptBegin not implemented");
        }

        public void AddHookAtInterruptEnd(Action<ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtInterruptEnd not implemented");
        }

        public void AddHook(ulong addr, Action<ICpuSupportingGdb, ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHook not implemented");
        }

        public void RemoveHook(ulong addr, Action<ICpuSupportingGdb, ulong> hook)
        {
            this.Log(LogLevel.Warning, "RemoveHook not implemented");
        }

        public void AddHookAtWfiStateChange(Action<bool> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtWfiStateChange not implemented");
        }

        public void RemoveHooksAt(ulong addr)
        {
            this.Log(LogLevel.Warning, "RemoveHooksAt not implemented");
        }

        public void RemoveAllHooks()
        {
            this.Log(LogLevel.Warning, "RemoveAllHooks not implemented");
        }

        public override string Architecture { get { return "riscv"; } }

        public string GDBArchitecture { get { return "riscv:rv32"; } }

        public List<GDBFeatureDescriptor> GDBFeatures { get { return new List<GDBFeatureDescriptor>(); } }
    }
}