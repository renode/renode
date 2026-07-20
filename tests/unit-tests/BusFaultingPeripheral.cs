//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.Mocks
{
    public class BusFaultingPeripheral : IDoubleWordPeripheral, IKnownSize
    {
        public uint ReadDoubleWord(long offset)
        {
            throw new BusAccessException(BusAccessError.AddressError);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            throw new BusAccessException(BusAccessError.AddressError);
        }

        public void Reset()
        {
        }

        public long Size => 0x1000;
    }
}
