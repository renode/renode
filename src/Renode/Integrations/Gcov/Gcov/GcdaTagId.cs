//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

namespace Antmicro.Renode.Integrations.Gcov
{
    public enum GcdaTagId
    {
        ObjectSummary = unchecked((int)0xa1000000),
        Function = 0x01000000,
        Counts = 0x01a10000,
    }
}
