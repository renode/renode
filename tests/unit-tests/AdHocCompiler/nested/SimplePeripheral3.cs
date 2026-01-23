//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Peripherals
{
    // This class is intentionally named differently than the file it is in to test path resolution logic
    public class NestedSimplePeripheral : BasicDoubleWordPeripheral, IKnownSize
    {
        public NestedSimplePeripheral(Machine machine) : base(machine)
        {
            IValueRegisterField value;

            Registers.Base.Define(this)
                .WithValueField(0, 32, out value, FieldMode.Write);

            Registers.Multiplier.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => value.Value * 2);

            Registers.BitCounter.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => (uint)BitHelper.GetBits(value.Value).Where(x => x).Select(x => 1).Sum(x => x));

            Registers.IsNested.Define(this, 1)
                .WithFlag(0, FieldMode.Read, name: "nested")
                .WithReservedBits(1, 31);
        }

        public long Size { get { return 0x100; } }

        private enum Registers : long
        {
            Base = 0x0,
            Multiplier = 0x04,
            BitCounter = 0x08,
            IsNested = 0x0c,
        }
    }
}
