//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
namespace Antmicro.Renode.PlatformDescription
{
    public interface IUsingResolver
    {
        string Resolve(string argument);
    }
}
