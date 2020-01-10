//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Threading;
using Antmicro.Renode;
using Antmicro.Renode.UI;
using System.IO;
using System;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.RobotFramework;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode
{
    public class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            AppDomain.CurrentDomain.ProcessExit += (_, __) => Emulator.Exit();

            ConfigureEnvironment();
            var thread = new Thread(() =>
            {
                var options = new Options();
                var optionsParser = new OptionsParser.OptionsParser();
                try
                {
                    if(optionsParser.Parse(options, args))
                    {
                        Antmicro.Renode.UI.CommandLineInterface.Run(options, (context) =>
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
            if(Misc.TryGetRootDirectory(out var rootDir))
            {
                var localConfig = Path.Combine(rootDir, "renode.config");
                if(File.Exists(localConfig))
                {
                    configFile = localConfig;
                }
            }

            ConfigurationManager.Initialize(configFile ?? Path.Combine(Emulator.UserDirectoryPath, "config"));

            // set Termsharp as a default terminal if there is none already
            ConfigurationManager.Instance.Get("general", "terminal", "Termsharp");
            ConsoleBackend.Instance.ReportRepeatingLines = !ConfigurationManager.Instance.Get("general", "collapse-repeated-log-entries", true);
        }
    }
}
