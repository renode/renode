//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class NumericalValue : Value
    {
        public NumericalValue(string value)
        {
            Value = value;
        }

        public override string ToString()
        {
            return string.Format("[NumericalValue: {0}]", Value);
        }

        public string Value { get; private set; }
    }
}
