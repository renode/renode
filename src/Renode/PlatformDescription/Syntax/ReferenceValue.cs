//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class ReferenceValue : Value, IPrefixable, IPositionAware<ReferenceValue>
    {
        public ReferenceValue(string value)
        {
            Value = value;
        }

        public override string ToString()
        {
            return string.Format("[ReferenceValue: {0}]", Value);
        }

        public void Prefix(string with)
        {
            Value = with + Value;
        }

        ReferenceValue IPositionAware<ReferenceValue>.SetPos(Position startPos, int length)
        {
            return (ReferenceValue)SetPos(startPos, length);
        }

        public string Value { get; private set; }
        public string Scope { get; set; }
    }
}
