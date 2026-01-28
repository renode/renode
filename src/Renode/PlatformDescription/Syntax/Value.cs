//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public abstract class Value : IPositionAware<Value>, IWithPosition, IVisitable
    {
        public Value SetPos(Position startPos, int length)
        {
            StartPosition = startPos;
            Length = length;
            return this;
        }

        public virtual IEnumerable<object> Visit()
        {
            return Enumerable.Empty<object>();
        }

        public Position StartPosition { get; private set; }

        public int Length { get; private set; }
    }
}
