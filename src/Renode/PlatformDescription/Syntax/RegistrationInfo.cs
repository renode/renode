//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Reflection;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class RegistrationInfo : IVisitable
    {
        public RegistrationInfo(ReferenceValue register, Value registrationPoint)
        {
            Register = register;
            RegistrationPoint = registrationPoint;
        }

        public IEnumerable<object> Visit()
        {
            return new[] { Register, RegistrationPoint };
        }

        public ReferenceValue Register { get; private set; }

        public Value RegistrationPoint { get; private set; }

        public ConstructorInfo Constructor { get; set; }

        public object ConvertedValue { get; set; }

        public Type RegistrationInterface { get; set; }
    }
}