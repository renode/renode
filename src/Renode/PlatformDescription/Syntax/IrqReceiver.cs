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
    public sealed class IrqReceiver : IPositionAware<IrqReceiver>, IWithPosition, IVisitable
    {
        public IrqReceiver(ReferenceValue reference, int? localIndex)
        {
            Reference = reference;
            LocalIndex = localIndex;
        }

        public IrqReceiver SetPos(Position startPos, int length)
        {
            StartPosition = startPos;
            Length = length;
            return this;
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
