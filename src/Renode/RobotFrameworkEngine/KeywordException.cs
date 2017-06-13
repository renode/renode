//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
namespace Antmicro.Renode.RobotFramework
{
    public class KeywordException : Exception
    {
        public KeywordException(string message, params object[] args) : base(string.Format(message, args))
        {
        }
    }
}

