//
// Copyright (c) 2010-2018 Antmicro
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