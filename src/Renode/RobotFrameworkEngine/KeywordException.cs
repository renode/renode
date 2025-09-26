//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.RobotFramework
{
    public class KeywordException : Exception
    {
        public KeywordException(string message) : base(message)
        {
        }

        public KeywordException(string message, params object[] args) : base(string.Format(message, args))
        {
        }
    }
}