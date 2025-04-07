//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.PlatformDescription.Syntax;

namespace Antmicro.Renode.PlatformDescription
{
    public class FakeScriptHandler : IScriptHandler
    {
        public void Execute(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler)
        {
        }

        public void RegisterReset(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler)
        {
        }

        public bool ValidateInit(IScriptable scriptable, out string message)
        {
            message = null;
            return true;
        }
    }
}