//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.Integrations.Gcov
{
    [Flags]
    public enum BranchFlags
    {
        None = 0,
        Tree = 1 << 0,
        Fake = 1 << 1,
        Fall = 1 << 2,
    }
}
