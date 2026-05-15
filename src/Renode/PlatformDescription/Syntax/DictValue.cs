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
    public sealed class KeyValuePair
    {
        public KeyValuePair(Value key, Value val)
        {
            Key = key;
            Val = val;
        }

        public override string ToString()
        {
            return string.Format("[KeyValuePair: {0}: {1}]", Key, Val);
        }

        public Value Key { get; private set; }

        public Value Val { get; private set; }
    }

    public sealed class DictValue : Value
    {
        public DictValue(IEnumerable<KeyValuePair> items)
        {
            if(items != null)
            {
                Items = items.ToDictionary(x => x.Key, x => x.Val);
            }
            else
            {
                Items = new Dictionary<Value, Value>();
            }
        }

        public override IEnumerable<object> Visit()
        {
            return Items.Keys.Concat(Items.Values);
        }

        public override string ToString()
        {
            return string.Format("[DictValue: {0}]", Items);
        }

        public readonly Dictionary<Value, Value> Items;
    }
}
