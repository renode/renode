//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public abstract class Attribute : IPositionAware<Attribute>, IWithPosition, IVisitable
    {
        public Attribute SetPos(Position startPos, int length)
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

        /// <summary>The entry where this attribute was originally defined. Should not be mutated after Entry construction.</summary>
        public Entry OriginalEntry
        {
            get => originalEntry;
            internal set
            {
                if(originalEntry != null)
                {
                    throw new InvalidOperationException($"Attempted to reparent attribute by changing {nameof(OriginalEntry)}");
                }
                originalEntry = value;
            }
        }

        private Entry originalEntry;
    }
}
