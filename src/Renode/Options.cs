//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using Antmicro.OptionsParser;

namespace Antmicro.Renode
{
    internal class Options : Emul8.CLI.Options
    {
        [Name("robot-framework-remote-server-port"), DefaultValue(-1), Description("Start robot framework remote server on the specified port.")]
        public int RobotFrameworkRemoteServerPort { get; set; }
    }
}

