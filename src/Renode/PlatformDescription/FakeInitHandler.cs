//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using Antmicro.Renode.PlatformDescription.Syntax;

namespace Antmicro.Renode.PlatformDescription
{
    public class FakeInitHandler : IInitHandler
    {
        public void Execute(IInitable initable, IEnumerable<string> statements, Action<string> errorHandler)
        {
        }

        public bool Validate(IInitable initable, out string message)
        {
            message = null;
            return true;
        }
    }
}
