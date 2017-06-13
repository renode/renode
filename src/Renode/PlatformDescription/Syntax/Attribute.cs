//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Antmicro.Migrant;
using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public abstract class Attribute : IPositionAware<Attribute>, IWithPosition, IVisitable
    {
        public Attribute SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.StartPosition = startPos;
            copy.Length = length;
            return copy;
        }

        public virtual IEnumerable<object> Visit()
        {
            return Enumerable.Empty<object>();
        }

        public Position StartPosition { get; private set; }
        public int Length { get; private set; }
    }
}
