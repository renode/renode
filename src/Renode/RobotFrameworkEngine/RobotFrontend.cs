//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Threading.Tasks;
using Emul8;
using Emul8.CLI;
using Emul8.Core;
using Emul8.Peripherals.UART;
using Emul8.UserInterface;
using Emul8.Utilities;

namespace Antmicro.Renode.RobotFramework
{
//    public class RobotFrontend
//    {
//        public static void Main(string[] args)
//        {
//            var options = new Antmicro.Renode.RobotFramework.Options();
//            var optionsParser = new Antmicro.OptionsParser.OptionsParser();
//            if(!optionsParser.Parse(options, args))
//            {
//                return;
//            }
//
//            var keywordManager = new KeywordManager();
//            TypeManager.Instance.AutoLoadedType += keywordManager.Register;
//
//            var processor = new XmlRpcServer(keywordManager);
//            server = new HttpServer(processor);
//
//            Task.Run(() =>
//            {
//                XwtProvider xwt = null;
//                try
//                {
//                    if(!options.DisableX11)
//                    {
//                        var preferredUARTAnalyzer = typeof(UARTWindowBackendAnalyzer);
//                        EmulationManager.Instance.CurrentEmulation.BackendManager.SetPreferredAnalyzer(typeof(UARTBackend), preferredUARTAnalyzer);
//                        EmulationManager.Instance.EmulationChanged += () =>
//                        {
//                            EmulationManager.Instance.CurrentEmulation.BackendManager.SetPreferredAnalyzer(typeof(UARTBackend), preferredUARTAnalyzer);
//                        };
//                        xwt = new XwtProvider(new WindowedUserInterfaceProvider());
//                    }
//
//                    using(var context = ObjectCreator.Instance.OpenContext())
//                    {
//                        var monitor = new Emul8.UserInterface.Monitor()  { Interaction = new CommandInteractionEater() };
//                        context.RegisterSurrogate(typeof(Emul8.UserInterface.Monitor), monitor);
//
//                        // we must initialize plugins AFTER registering monitor surrogate
//                        // as some plugins might need it for construction
//                        TypeManager.Instance.PluginManager.Init("CLI");
//
//                        server.Run(options.Port);
//                        server.Dispose();
//                    }
//                }
//                finally
//                {
//                    if(xwt != null)
//                    {
//                        xwt.Dispose();
//                    }
//                    Emulator.FinishExecutionAsMainThread();
//                }
//            });
//
//            Emulator.ExecuteAsMainThread();
//        }
//
//        public static void ExecuteKeyword(string name, string[] arguments)
//        {
//            server.Processor.RunKeyword(name, arguments);
//        }
//
//        public static void Shutdown()
//        {
//            server.Shutdown();
//        }
//
//        private static HttpServer server;
//    }
}
