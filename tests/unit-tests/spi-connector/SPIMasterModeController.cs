//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Timers;

namespace Antmicro.Renode.Peripherals.SPI
{
    public class SPIMasterModeController : NullRegistrationPointPeripheralContainer<ISPIPeripheral>, IDoubleWordPeripheral, IKnownSize
    {
        public SPIMasterModeController(Machine machine) : base(machine)
        {
            counter = 0;
            timer = new LimitTimer(machine.ClockSource, 750, this, "master_clk", workMode: WorkMode.Periodic, eventEnabled: true, limit: 1, enabled: true);
            timer.LimitReached += () =>
            {
                var output = RegisteredPeripheral.Transmit(counter);
                this.Log(LogLevel.Info, "Master sent:{0} received:{1}", counter, output);
                counter++;
                if(SendTwice)
                {
                    output = RegisteredPeripheral.Transmit(counter);
                    this.Log(LogLevel.Info, "Master sent:{0} received:{1}", counter, output);
                    counter++;
                }
                if(counter > CounterMax)
                {
                    RegisteredPeripheral.FinishTransmission();
                    timer.Enabled = false;
                }
            };
        }

        public uint ReadDoubleWord(long offset)
        {
            return 0x0;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
        }

        public override void Reset()
        {
            counter = 0;
            timer.Enabled = true;
        }

        public bool SendTwice { get; set; }

        public long Size => 0x100;

        private byte counter;
        private LimitTimer timer;

        private readonly byte CounterMax = 10;
    }
}
