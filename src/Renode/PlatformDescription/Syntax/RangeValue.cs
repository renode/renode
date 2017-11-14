//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Antmicro.Renode.Core;

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
