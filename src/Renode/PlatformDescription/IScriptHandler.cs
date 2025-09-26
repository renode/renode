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
    public interface IScriptHandler
    {
        bool ValidateInit(IScriptable scriptable, out string message);

        void RegisterReset(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler);

        void Execute(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler);
    }
}