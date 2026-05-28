//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class ListValue : Value
    {
        public ListValue(IEnumerable<Value> items)
        {
            Items = items.ToList();
        }

        public override IEnumerable<object> Visit()
        {
            return Items;
        }

        public override string ToString()
        {
            return string.Format("[ListValue: {0}]", Items);
        }

        public readonly List<Value> Items;
    }
}
