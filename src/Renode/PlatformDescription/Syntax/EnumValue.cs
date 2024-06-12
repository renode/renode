//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Sprache;
using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{

    public sealed class EnumValue : Value
    {
        public EnumValue(IEnumerable<string> elements)
        {
            var nameSpaceAndType = new Stack<string>();
            foreach(var element in elements)
            {
                nameSpaceAndType.Push(element);
            }
            Value = nameSpaceAndType.Pop();
            TypeName = nameSpaceAndType.Pop();
            ReversedNamespace = nameSpaceAndType;
        }

        public override string ToString()
        {
            return string.Format("[EnumValue: {0}]", ToShortString());
        }

        public string ToShortString()
        {
            return ReversedNamespace.Reverse().Concat(new[] { TypeName, Value }).Aggregate((x, y) => x + '.' + y);
        }

        public IEnumerable<string> ReversedNamespace { get; private set; }
        public string Value { get; private set; }
        public string TypeName { get; }
    }
}
