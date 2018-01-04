//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.OptionsParser;

namespace Antmicro.Renode
{
    internal class Options : Antmicro.Renode.UI.Options
    {
        [Name("robot-server-port"), DefaultValue(-1), Description("Start robot framework remote server on the specified port.")]
        public int RobotFrameworkRemoteServerPort { get; set; }
    }
}

