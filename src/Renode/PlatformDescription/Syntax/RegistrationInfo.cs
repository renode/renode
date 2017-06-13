//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
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
