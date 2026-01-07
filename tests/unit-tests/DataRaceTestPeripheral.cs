using System;
using System.Threading;
using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals
{
    /// <summary>
    /// A peripheral used to test the mutual exclusion of sysbus accesses
    /// </summary>
    public class DataRaceTestPeripheral : BasicDoubleWordPeripheral, IKnownSize
    {
        public DataRaceTestPeripheral(Machine machine) : base(machine)
        {
            Registers.Reg0.Define(this).
                WithValueField(0, 32);
        }

        public override uint ReadDoubleWord(long offset)
        {
            var old_value = base.ReadDoubleWord(offset);
            Thread.Sleep(100);
            var new_value = base.ReadDoubleWord(offset);
            if(old_value != new_value)
            {
                this.ErrorLog("Should not happen");
            }
            return new_value;
        }

        public long Size { get { return 0x100; } }

        private enum Registers : long
        {
            Reg0 = 0x0,
        }
    }
}
