//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.RobotFramework;

namespace Antmicro.Renode.RobotFramework
{
    internal class CpuKeywords : IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public void PcShouldBeEqual(ulong value, string machine = null, int? cpuId = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);

            var actual = GetCPU(machineObj, cpuId).PC.RawValue;

            if(actual != value)
            {
                throw new KeywordException($"PC value assertion failed, actual: 0x{actual:x}, expected: 0x{value:x}");
            }
        }

        [RobotFrameworkKeyword]
        public void RegisterShouldBeEqual(int register, ulong value, string machine = null, int? cpuId = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);

            var controllableCpu = GetCPU(machineObj, cpuId) as IControllableCPU;
            if(controllableCpu == null)
            {
                throw new KeywordException("This CPU is not a controllable CPU.");
            }

            var actual = controllableCpu.GetRegisterUnsafe(register).RawValue;

            if(actual != value)
            {
                throw new KeywordException($"Register {register} value assertion failed, actual: 0x{actual:x}, expected: 0x{value:x}");
            }
        }

        private string GetMachineNames(Emulation emulation)
        {
            return string.Join(", ", emulation.Machines.Select(mach => emulation[mach]));
        }

        private Machine GetMachineByNameOrSingle(string machineName = null)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            Machine machine;

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

        private ICPU GetCPU(Machine machine, int? cpuId)
        {
            var sysbus = machine.SystemBus;
            var cpus = sysbus.GetCPUs();

            if(cpus.Count() == 0)
            {
                throw new KeywordException("This machine has no CPUs.");
            }

            if(cpuId == null)
            {
                if(cpus.Count() == 1)
                {
                    return cpus.Single();
                }
                else
                {
                    throw new KeywordException("This machine has {0} CPUs and no CPU ID was specified.", cpus.Count());
                }
            }

            var selectedCpu = cpus.SingleOrDefault(cpu => sysbus.GetCPUId(cpu) == cpuId);
            if(selectedCpu == null)
            {
                throw new KeywordException($"This machine has no CPU with ID {cpuId}");
            }

            return selectedCpu;
        }
    }
}
