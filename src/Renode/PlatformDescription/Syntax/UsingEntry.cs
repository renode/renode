//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class UsingEntry : IPositionAware<UsingEntry>, IWithPosition, IVisitable
    {
        public UsingEntry(StringWithPosition path, string prefix)
        {
            Path = path;
            Prefix = prefix;
        }

        public UsingEntry SetPos(Position startPos, int length)
        {
            StartPosition = startPos;
            Length = length;
            return this;
        }

        public IEnumerable<object> Visit()
        {
            return new[] { Path };
        }

        public StringWithPosition Path { get; private set; }

        public string Prefix { get; private set; }

        public Position StartPosition { get; private set; }

        public int Length { get; private set; }
    }
}
