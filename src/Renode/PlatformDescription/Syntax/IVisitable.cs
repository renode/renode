//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public interface IVisitable
    {
        IEnumerable<object> Visit();
    }
}