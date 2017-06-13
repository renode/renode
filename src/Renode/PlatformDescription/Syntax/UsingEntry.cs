//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Collections.Generic;
using Antmicro.Migrant;
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

        public IEnumerable<object> Visit()
        {
            return new[] { Path };
        }

        public StringWithPosition Path { get; private set; }
        public string Prefix { get; private set; }

        public Position StartPosition { get; private set; }

        public int Length { get; private set; }

        public UsingEntry SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.StartPosition = startPos;
            copy.Length = length;
            return copy;
        }
    }
}
