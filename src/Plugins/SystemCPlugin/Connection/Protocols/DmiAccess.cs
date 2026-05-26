//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.Peripherals.SystemC
{
    /// <summary>
    /// It corresponds to tlm::tlm_dmi::dmi_access_e.
    /// </summary>
    [Flags]
    public enum DmiAccess : byte
    {
        None = 0,
        Read = 1 << 0,
        Write = 1 << 1,
        ReadWrite = Read | Write,
    }
}
