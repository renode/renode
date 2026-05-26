//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Peripherals.SystemC
{
    /// <summary>
    /// It corresponds to tlm::tlm_command.
    /// </summary>
    public enum TlmCommand : byte
    {
        Read = 0,
        Write = 1,
        Ignore = 2,
    }
}
