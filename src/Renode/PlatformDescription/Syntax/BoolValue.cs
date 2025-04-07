//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class BoolValue : Value, ISimplestValue
    {
        public BoolValue(bool value)
        {
            Value = value;
        }

        public override string ToString()
        {
            return string.Format("[BoolValue: {0}]", Value);
        }

        public bool Value { get; private set; }

        public object ConvertedValue
        {
            get
            {
                return Value;
            }
        }
    }
}