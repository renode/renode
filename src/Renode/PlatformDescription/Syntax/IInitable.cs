//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Collections.Generic;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public interface IInitable : IWithPosition
    {
        IEnumerable<Attribute> Attributes { get; }
    }
}
