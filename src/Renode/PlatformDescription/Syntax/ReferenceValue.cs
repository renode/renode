//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class ReferenceValue : Value, IPositionAware<ReferenceValue>
    {
        public ReferenceValue(string value)
        {
            Value = value;
            baseValue = value;
        }

        public override string ToString()
        {
            return $"[ReferenceValue: {Value}]";
        }

        public string ToShortString()
        {
            return $"{Value}";
        }

        ReferenceValue IPositionAware<ReferenceValue>.SetPos(Position startPos, int length)
        {
            return (ReferenceValue)SetPos(startPos, length);
        }

        public string Value { get; private set; }

        public string Scope { get; set; }

        private readonly string baseValue;
    }
}