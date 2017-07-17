//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System.Threading;
using Emul8;
using System.IO;
using System;
using Emul8.Utilities;
using Antmicro.Renode.RobotFramework;
using Emul8.Logging;

namespace Antmicro.Renode
{
    public class Program
    {
        public static void Main(string[] args)
        {
            ConfigureEnvironment();
            var thread = new Thread(() =>
            {
                var options = new Options();
                var optionsParser = new OptionsParser.OptionsParser();
                try
                {
                    if(optionsParser.Parse(options, args))
                    {
                        Emul8.CLI.CommandLineInterface.Run(options, (context) =>
                        {
                            if(options.RobotFrameworkRemoteServerPort >= 0)
                            {
                                var rf = new RobotFrameworkEngine();
                                context.RegisterSurrogate(typeof(RobotFrameworkEngine), rf);
                                rf.Start(options.RobotFrameworkRemoteServerPort);
                            }
                        });
                    }
                }
                finally
                {
                    Emulator.FinishExecutionAsMainThread();
                }
            });
            thread.Start();
            Emulator.ExecuteAsMainThread();
        }

        private static void ConfigureEnvironment()
        {
            ConsoleBackend.Instance.WindowTitle = "Renode";

            string configFile = null;
            string emul8Dir;
            if(Misc.TryGetEmul8Directory(out emul8Dir))
            {
                var localConfig = Path.Combine(emul8Dir, "renode.config");
                if(File.Exists(localConfig))
                {
                    configFile = localConfig;
                }
            }

            Emulator.UserDirectoryPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal), ".renode");
            ConfigurationManager.Initialize(configFile ?? Path.Combine(Emulator.UserDirectoryPath, "config"));
            TemporaryFilesManager.Initialize(Path.GetTempPath(), "renode-");
        }
    }
}
