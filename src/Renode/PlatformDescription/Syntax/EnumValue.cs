//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
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
