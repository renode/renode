//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//

using Emul8.Core;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class RangeValue : Value, ISimplestValue
    {
        public RangeValue(long begin, long end)
        {
            Begin = begin;
            End = end;
        }

        public Range ToRange()
        {
            return new Range(Begin, End - Begin);
        }

        public override string ToString()
        {
            return string.Format("[RangeValue: {0}]", ToRange());
        }

        public object ConvertedValue
        {
            get
            {
                return ToRange();
            }
        }

        public long Begin { get; private set; }
        public long End { get; private set; }
    }
}
