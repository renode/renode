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

            var options = new Options();
            var optionsParser = new OptionsParser.OptionsParser();
            var optionsParsed = optionsParser.Parse(options, args);

            ConfigureEnvironment(options);
            var thread = new Thread(() =>
            {
                try
                {
                    if(optionsParsed)
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

        private static void ConfigureEnvironment(Options options)
        {
            //Plain mode must be set before the window title
            ConsoleBackend.Instance.PlainMode = options.Plain;
            ConsoleBackend.Instance.WindowTitle = "Renode";

            string configFile = null;

            if(options.ConfigFile != null)
            {
                configFile = options.ConfigFile;
            }
            else if(Misc.TryGetRootDirectory(out var rootDir))
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
