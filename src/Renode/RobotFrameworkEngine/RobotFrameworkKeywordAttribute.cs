//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.RobotFramework
{
    public class RobotFrameworkKeywordAttribute : Attribute
    {
        public RobotFrameworkKeywordAttribute()
        {
        }

        public RobotFrameworkKeywordAttribute(string name)
        {
            Name = name;
        }

        public string Name { get; private set; }
    }
}

