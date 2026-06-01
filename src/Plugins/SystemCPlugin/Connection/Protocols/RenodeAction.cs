//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Peripherals.SystemC
{
    public enum RenodeAction : byte
    {
        Init = 0,
        Read = 1,
        Write = 2,
        Timesync = 3,
        GPIOWrite = 4,
        Reset = 5,
        DMIReq = 6,
        InvalidateTBs = 7,
        ReadRegister = 8,
        WriteRegister = 9,
        InitSecureVTOR = 10,
        InitNonSecureVTOR = 11,
        InvalidateDmiRange = 12,
    }
}
