//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Threading;
using Antmicro.Renode;
using Antmicro.Renode.UI;
using System.Reflection;
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
            if (!optionsParsed)
            {
                return;
            }
            if(options.Version)
            {
                Console.Out.WriteLine(LongVersionString);
                return;
            }
            ConfigureEnvironment(options);

            /* 
                We noticed that the static constructors' initialization chain breaks non-deterministically on some Mono versions crashing Renode with NullReferenceException.
                In the current version, EmulationManager's static constructor calls TypeManager that in turn uses Logger; Logger however requires EmulationManager to be functional.
                This circular dependency seems to be a problem.
                Here we explicitly initialize EmulationManager as this seems to resolve the problem. This is just a workaround, until we refactor the code of the initialization phase.
            */
            Core.EmulationManager.RebuildInstance();

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

        private static string LongVersionString
        {
            get
            {
                var entryAssembly = Assembly.GetEntryAssembly();
                try
                {
                    var name = entryAssembly == null ? "Unknown assembly name" : entryAssembly.GetName().Name;
                    var version = entryAssembly == null ? ": Unknown version" : entryAssembly.GetName().Version.ToString();
#if NET
                    var runtime = ".NET";
#elif PLATFORM_WINDOWS
                    var runtime = ".NET Framework";
#else
                    var runtime = "Mono";
#endif
                    return string.Format("{0} v{1}\n  build: {2}\n  build type: {3}\n  runtime: {4} {5}",
                        name,
                        version,
                        ((AssemblyInformationalVersionAttribute)entryAssembly.GetCustomAttributes(typeof(AssemblyInformationalVersionAttribute), false)[0]).InformationalVersion,
                        ((AssemblyConfigurationAttribute)entryAssembly.GetCustomAttributes(typeof(AssemblyConfigurationAttribute), false)[0]).Configuration,
                        runtime,
                        Environment.Version
                    );
                }
                catch(Exception)
                {
                    return string.Empty;
                }
            }
        }
    }
}
