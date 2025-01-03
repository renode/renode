//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Linq;
using System.Text;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.CPU
{
    public class SampleStateAwarePeripheral : IDoubleWordPeripheral, IKnownSize
    {
        public SampleStateAwarePeripheral(IMachine machine, long size)
        {
            this.size = size;
            sysbus = machine.GetSystemBus(this);
        }

        public void Reset()
        {
        }

        public uint ReadDoubleWord(long offset)
        {
            if(!sysbus.TryGetCurrentContextState<CortexM.ContextState>(out var initiator, out var cpuState))
            {
                this.WarningLog("No context");
                return 0;
            }
            var peripheralName = initiator.GetName().Split('.')[1];
            bool privileged = (bool)cpuState.Privileged, cpuSecure = (bool)cpuState.CpuSecure, attributionSecure = (bool)cpuState.AttributionSecure;
            this.WarningLog("Read from context: {0} state.Privileged: {1}, state.CpuSecure: {2}, state.AttributionSecure: {3}", peripheralName, privileged, cpuSecure, attributionSecure);
            var peripheralNameBytes = Encoding.UTF8.GetBytes(peripheralName).Take(3).Aggregate(0U, (v, b) => (v << 8) | b);
            return (peripheralNameBytes << 8) | ((privileged ? 1u : 0) << 0) | ((cpuSecure ? 1u : 0) << 1) | ((attributionSecure ? 1u : 0) << 2);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
        }

        public long Size => size;

        private readonly long size;
        private readonly IBusController sysbus;
    }
}
