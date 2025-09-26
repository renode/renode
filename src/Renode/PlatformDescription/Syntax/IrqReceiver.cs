//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class IrqReceiver : IPositionAware<IrqReceiver>, IWithPosition, IVisitable
    {
        public IrqReceiver(ReferenceValue reference, int? localIndex)
        {
            Reference = reference;
            LocalIndex = localIndex;
        }

        public IrqReceiver SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.StartPosition = startPos;
            copy.Length = length;
            return copy;
        }

        public string ToShortString()
        {
            return Reference.ToShortString() + (LocalIndex != null ? "#" + LocalIndex.ToString() : "");
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