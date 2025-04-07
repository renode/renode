//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading.Tasks;

using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    public class RobotFrameworkEngine
    {
        public RobotFrameworkEngine()
        {
            keywordManager = new KeywordManager();
            TypeManager.Instance.AutoLoadedType += keywordManager.Register;

            var processor = new XmlRpcServer(keywordManager);
            server = new HttpServer(processor);
        }

        public void Start(int port)
        {
            Task.Run(() =>
            {
                try
                {
                    server.Run(port);
                    server.Dispose();
                }
                finally
                {
                    Emulator.Exit();
                    Emulator.FinishExecutionAsMainThread();
                }
            });
        }

        public void ExecuteKeyword(string name, object[] arguments)
        {
            if(keywordManager.TryExecuteKeyword(name, arguments, out var _) != KeywordManager.KeywordLookupResult.Success)
            {
                throw new ArgumentException($"Could not find the '{name}' keyword with matching arguments, although it was used previously. It might indicate an internal error.");
            }
        }

        public void Shutdown()
        {
            server.Shutdown();
        }

        private readonly HttpServer server;
        private readonly KeywordManager keywordManager;
    }
}