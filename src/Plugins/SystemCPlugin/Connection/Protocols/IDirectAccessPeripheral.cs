//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Peripherals.SystemC
{
    public interface IDirectAccessPeripheral : IPeripheral
    {
        ulong ReadDirect(byte dataLength, long offset, byte connectionIndex);

        void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex);
    }
}
