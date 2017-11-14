//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
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
