//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Antmicro.Renode.Core;

namespace Antmicro.Renode.Peripherals
{
    public class UnimplementedRegistersPeripheral : BasicDoubleWordPeripheral, IKnownSize
    {
        public UnimplementedRegistersPeripheral(Machine machine) : base(machine)
        {
            // Don't define any registers.
        }

        public long Size => 0x100;

        private enum Registers
        {
            First = 0x0,
            Second = 0x04,
            Third = 0x08,
        }
    }
}
