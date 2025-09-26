//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class RangeValue : Value, ISimplestValue
    {
        public RangeValue(ulong begin, ulong end)
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

        public ulong Begin { get; private set; }

        public ulong End { get; private set; }
    }
}