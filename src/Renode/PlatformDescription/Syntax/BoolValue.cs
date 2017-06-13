//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
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
