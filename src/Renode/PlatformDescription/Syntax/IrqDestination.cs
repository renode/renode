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
    public sealed class IrqDestination : IPositionAware<IrqDestination>, IWithPosition, IVisitable
    {
        public IrqDestination(ReferenceValue reference, int? localIndex)
        {
            Reference = reference;
            LocalIndex = localIndex;
        }

        public IrqDestination SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
        	copy.StartPosition = startPos;
        	copy.Length = length;
        	return copy;
        }

        public string ToShortString()
        {
            return Reference + (LocalIndex != null ? "#" + LocalIndex.ToString() : "");
        }

        public IEnumerable<object> Visit()
        {
            return new[] { Reference };
        }

        public ReferenceValue Reference { get; private set; }
        public int? LocalIndex { get; private set; }
        public Position StartPosition { get; private set; }
        public int Length { get; private set; }
    }
}
