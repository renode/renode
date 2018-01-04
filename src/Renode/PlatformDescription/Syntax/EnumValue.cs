//
// Copyright (c) 2010-2018 Antmicro
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
            TypeAndReversedNamespace = nameSpaceAndType;
        }

        public override string ToString()
        {
            return string.Format("[EnumValue: {0}]", ToShortString());
        }

        public string ToShortString()
        {
            return TypeAndReversedNamespace.Reverse().Concat(new[] { Value }).Aggregate((x, y) => x + '.' + y);
        }

        public IEnumerable<string> TypeAndReversedNamespace { get; private set; }
        public string Value { get; private set; }
    }
}
