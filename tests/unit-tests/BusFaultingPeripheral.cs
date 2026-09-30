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
    [AllowedTranslations(AllowedTranslation.WordToByte | AllowedTranslation.DoubleWordToByte | AllowedTranslation.QuadWordToByte)]
    public class BusFaultingPeripheral : IBytePeripheral, IKnownSize
    {
        public BusFaultingPeripheral()
        {
            data = new byte[Size];
        }

        public byte ReadByte(long offset)
        {
            ThrowIfConfigured(offset, isWrite: false);
            return data[offset];
        }

        public void WriteByte(long offset, byte value)
        {
            ThrowIfConfigured(offset, isWrite: true);
            data[offset] = value;
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

        private readonly byte[] data;

        public bool FaultOnReads { get; set; } = true;
        public bool FaultOnWrites { get; set; } = true;
    }
}
