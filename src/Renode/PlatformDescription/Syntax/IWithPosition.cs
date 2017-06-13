//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public interface IWithPosition
    {
        Position StartPosition { get; }
        int Length { get; }
    }
}
