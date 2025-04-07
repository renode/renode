//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.RobotFramework
{
    public class RobotFrameworkKeywordAttribute : Attribute
    {
        public RobotFrameworkKeywordAttribute(string name = null, Replay replayMode = Replay.InReexecutionMode)
        {
            Name = name;
            ReplayMode = replayMode;
        }

        public string Name { get; private set; }

        public Replay ReplayMode { get; private set; }
    }

    public enum Replay
    {
        Always,
        Never,
        InReexecutionMode,
        InSerializationMode,
    }
}