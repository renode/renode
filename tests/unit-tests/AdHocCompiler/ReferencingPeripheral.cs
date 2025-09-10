//
// Copyright (c) 2010-2025 Antmicro
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
    public class ReferencingPeripheral : BasicDoubleWordPeripheral, IKnownSize
    {
        public ReferencingPeripheral(Machine machine) : base(machine)
        {
            IValueRegisterField value;

            Registers.Base.Define(this)
                .WithValueField(0, 32, out value, FieldMode.Write);

            Registers.Multiplier.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => value.Value * 2);

            Registers.BitCounter.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => (uint)BitHelper.GetBits(value.Value).Where(x => x).Select(x => 1).Sum(x => x));
        }

        public long Size => ReferencedType.Size;

        private enum Registers : long
        {
            Base = 0x0,
            Multiplier = 0x04,
            BitCounter = 0x08,
        }
    }
}
