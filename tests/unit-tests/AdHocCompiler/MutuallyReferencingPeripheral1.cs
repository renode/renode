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
    public class MutuallyReferencingPeripheral1 : BasicDoubleWordPeripheral, IKnownSize
    {
        public MutuallyReferencingPeripheral1(Machine machine) : base(machine)
        {
            Registers.OwnValue.Define(this)
                .WithValueField(0, 32, out Value);

            Registers.OtherValue.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => Other.Value.Value, writeCallback: (_, val) => Other.Value.Value = val);
        }

        public long Size => 0x100;

        public IValueRegisterField Value;

        public MutuallyReferencingPeripheral2 Other { get; set; }

        private enum Registers : long
        {
            OwnValue = 0x0,
            OtherValue = 0x4,
        }
    }
}
