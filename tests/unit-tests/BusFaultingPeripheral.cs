//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.Mocks
{
    [AllowedTranslations(AllowedTranslation.ByteToDoubleWord | AllowedTranslation.WordToDoubleWord | AllowedTranslation.QuadWordToDoubleWord)]
    public class BusFaultingPeripheral : IDoubleWordPeripheral, IKnownSize
    {
        public BusFaultingPeripheral()
        {
            data = new uint[(int)(Size / sizeof(uint))];
        }

        public uint ReadDoubleWord(long offset)
        {
            ThrowIfConfigured(offset, isWrite: false);
            return data[(int)(offset / sizeof(uint))];
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            ThrowIfConfigured(offset, isWrite: true);
            data[(int)(offset / sizeof(uint))] = value;
        }

        public void Reset()
        {
            Array.Clear(data, 0, data.Length);
        }

        public long Size => 0x1000;

        // FaultOffset == null faults on every access.
        public long? FaultOffset { get; set; } = null;

        private void ThrowIfConfigured(long offset, bool isWrite)
        {
            if((FaultOffset is null || offset == FaultOffset) && (isWrite ? FaultOnWrites : FaultOnReads))
            {
                throw new BusAccessException(BusAccessError.AddressError);
            }
        }

        private readonly uint[] data;

        public bool FaultOnReads { get; set; } = true;
        public bool FaultOnWrites { get; set; } = true;
    }
}
