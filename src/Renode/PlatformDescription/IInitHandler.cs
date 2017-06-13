//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Collections.Generic;
using Antmicro.Renode.PlatformDescription.Syntax;

namespace Antmicro.Renode.PlatformDescription
{
    public interface IInitHandler
    {
        bool Validate(IInitable initable, out string message);
        void Execute(IInitable initable, IEnumerable<string> statements, Action<string> errorHandler);
    }
}
