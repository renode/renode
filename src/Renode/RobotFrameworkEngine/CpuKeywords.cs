//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    internal class CpuKeywords : IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public void PcShouldBeEqual(ulong value, string machine = null, string cpuName = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);

            var actual = GetCPU(machineObj, cpuName).PC.RawValue;

            if(actual != value)
            {
                throw new KeywordException($"PC value assertion failed, actual: 0x{actual:x}, expected: 0x{value:x}");
            }
        }

        [RobotFrameworkKeyword]
        public void RegisterShouldBeEqual(int register, ulong value, string machine = null, string cpuName = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);

            var cpu = GetCPU(machineObj, cpuName) as ICPUWithRegisters;
            if(cpu == null)
            {
                throw new KeywordException("This CPU does not allow to access registers");
            }

            var actual = cpu.GetRegister(register).RawValue;

            if(actual != value)
            {
                throw new KeywordException($"Register {register} value assertion failed, actual: 0x{actual:x}, expected: 0x{value:x}");
            }
        }

        [RobotFrameworkKeyword]
        public void RunUntilBreakpoint(float timeout, string machine = null, string cpuName = null, ulong? address = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var cpu = GetCPU(machineObj, cpuName) as BaseCPU;

            var masterTimeSource = EmulationManager.Instance.CurrentEmulation.MasterTimeSource;

            var mre = new System.Threading.ManualResetEvent(false);
            var callback = (Action<HaltArguments>)((HaltArguments args) =>
            {
                if(address.HasValue && args.Address != address)
                {
                    return;
                }

                if(args.Reason == HaltReason.Breakpoint)
                {
                    mre.Set();
                }
            });

            var timeoutEvent = masterTimeSource.EnqueueTimeoutEvent((uint)(timeout * 1000));

            try
            {
                cpu.Halted += callback;
                EmulationManager.Instance.CurrentEmulation.StartAll();
                System.Threading.WaitHandle.WaitAny(new[] { timeoutEvent.WaitHandle, mre });
                EmulationManager.Instance.CurrentEmulation.PauseAll();

                if(timeoutEvent.IsTriggered)
                {
                    throw new KeywordException($"Breakpoint hasn't been hit in excepted time of {timeout} seconds.");
                }
            }
            finally
            {
                cpu.Halted -= callback;
            }
        }

        private string GetMachineNames(Emulation emulation)
        {
            return string.Join(", ", emulation.Machines.Select(mach => emulation[mach]));
        }

        private IMachine GetMachineByNameOrSingle(string machineName = null)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            IMachine machine;

            if(machineName == null)
            {
                if(emulation.MachinesCount == 0)
                {
                    throw new KeywordException("There are no machines in the emulation.");
                }

                if(emulation.MachinesCount > 1)
                {
                    throw new KeywordException("There is more than 1 machine and no machine name was specified. Available machines: [{0}]",
                        GetMachineNames(emulation));
                }

                machine = emulation.Machines.Single();
            }
            else if(!emulation.TryGetMachineByName(machineName, out machine))
            {
                throw new KeywordException("Machine with name {0} not found. Available machines: [{1}]",
                    machineName, GetMachineNames(emulation));
            }

            return machine;
        }

        private ICPU GetCPU(IMachine machine, string name = null)
        {
            var sysbus = machine.SystemBus;
            var cpus = sysbus.GetCPUs();

            if(cpus.Count() == 0)
            {
                throw new KeywordException("This machine has no CPUs.");
            }

            if(String.IsNullOrEmpty(name))
            {
                if(cpus.Count() == 1)
                {
                    return cpus.Single();
                }
                else
                {
                    throw new KeywordException("This machine has {0} CPUs and no CPU name was specified", cpus.Count());
                }
            }

            var selectedCpu = cpus.SingleOrDefault(c => machine.GetLocalName(c) == name);
            if(selectedCpu == default(ICPU))
            {
                throw new KeywordException($"This machine has no CPU named: {name}, available are: {String.Join(", ", cpus.Select(c => machine.GetLocalName(c)))}");
            }

            return selectedCpu;
        }
    }
}