//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Core;
using Antmicro.Renode.Time;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals.Mocks
{
    public class TestPeripheral : BasicBytePeripheral, IKnownSize
    {
        public TestPeripheral(IMachine machine) : base(machine)
        {
            DefineRegisters();
        }

        public void SetDelay(ulong microseconds)
        {
            this.delay = microseconds;
        }

        public long Size => 0x100;

        protected override void DefineRegisters()
        {
            Registers.Reg0.Define(this)
                .WithValueField(0, 8, FieldMode.Write, writeCallback: (_, value) =>
                {
                    var cts = machine.ElapsedVirtualTime.TimeElapsed;
                    this.Log(LogLevel.Info, "Written value 0x{0:X} to Reg0; current timestamp is {1}", value, cts);
                    this.Log(LogLevel.Info, "Scheduling delayed action in {0}us", delay);

                    machine.ScheduleAction(TimeInterval.FromMicroseconds(delay), (___) =>
                    {
                        var cts2 = machine.ElapsedVirtualTime.TimeElapsed;
                        this.Log(LogLevel.Info, "Executing scheduled action for Reg0; current timestamp is {0}", cts2);
                    });
                });
        }

        private ulong delay;

        private enum Registers : long
        {
            Reg0 = 0x0,
        }
    }
}
