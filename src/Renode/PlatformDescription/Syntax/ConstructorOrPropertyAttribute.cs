//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Reflection;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class ConstructorOrPropertyAttribute : Attribute
    {
        public ConstructorOrPropertyAttribute(string name, Value value)
        {
            Name = name;
            Value = value;
        }

        public override string ToString()
        {
            return string.Format("[ConstructorOrProperty: {0}: {1}]", Name, Value);
        }

        public override IEnumerable<object> Visit()
        {
            return new[] { Value };
        }

        public string Name { get; private set; }

        public Value Value { get; private set; }

        public PropertyInfo Property { get; set; }

        public bool IsPropertyAttribute
        {
            get
            {
                return char.IsUpper(Name[0]);
            }
        }
    }

    // the class is there because we are not able to have position aware IEnumerable
}