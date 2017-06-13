//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public interface IPrefixable
    {
        void Prefix(string with);
    }
}
