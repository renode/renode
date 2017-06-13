//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class ObjectValue : Value, IInitable
    {
        public ObjectValue(StringWithPosition typeName, IEnumerable<Attribute> attributes)
        {
            TypeName = typeName;
            Attributes = attributes;
        }

        public override string ToString()
        {
            return string.Format("[ObjectValue: TypeName={0}]", TypeName);
        }

        public override IEnumerable<object> Visit()
        {
            return (Attributes ?? Enumerable.Empty<Attribute>()).Cast<object>().Concat(new[] { TypeName });
        }

        public StringWithPosition TypeName { get; private set; }
        public IEnumerable<Attribute> Attributes { get; private set; }
        public ConstructorInfo Constructor { get; set; }
        public Type ObjectValueType { get; set; }
        public object Object { get; set; }
    }
}
