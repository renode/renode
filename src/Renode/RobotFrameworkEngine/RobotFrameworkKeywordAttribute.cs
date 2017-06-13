//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
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

