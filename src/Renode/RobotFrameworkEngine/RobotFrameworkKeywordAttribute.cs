//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.RobotFramework
{
    public class RobotFrameworkKeywordAttribute : Attribute
    {
        public RobotFrameworkKeywordAttribute(string name = null, bool shouldNotBeReplayed = false)
        {
            Name = name;
            ShouldNotBeReplayed = shouldNotBeReplayed;
        }

        public string Name { get; private set; }
        public bool ShouldNotBeReplayed { get; private set; }
    }
}

