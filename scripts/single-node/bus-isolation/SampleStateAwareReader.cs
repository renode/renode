//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.CPU
{
    public class SampleStateAwareReader : IBusPeripheral
    {
        public SampleStateAwareReader(Machine machine)
        {
            sysbus = machine.GetSystemBus(this);
        }

        public void Reset()
        {
        }

        public uint Read(ulong address, ulong state)
        {
            return sysbus.ReadDoubleWord(address, context: this, cpuState: state);
        }

        private IBusController sysbus;
    }
}
