//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
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