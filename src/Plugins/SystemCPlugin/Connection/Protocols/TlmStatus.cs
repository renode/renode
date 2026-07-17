//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Peripherals.SystemC
{
    /// <summary>
    /// It corresponds to tlm::tlm_response_status.
    /// Values are shifted by one and negated to make
    /// scale positive with 0 corresponding to OK.
    /// </summary>
    public enum TlmStatus : byte
    {
        Ok = 0,
        Incomplete = 1,
        GenericError = 2,
        AddressError = 3,
        CommandError = 4,
        BurstError = 5,
        ByteEnableError = 6,
    }
}
