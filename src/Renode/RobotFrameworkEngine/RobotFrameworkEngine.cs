using System;
using System.Threading.Tasks;
using Antmicro.Renode;
using Antmicro.Renode.Core;
using Antmicro.Renode.UserInterface;
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

        public void ExecuteKeyword(string name, string[] arguments)
        {
            if(!keywordManager.TryGetKeyword(name, out var keywords))
            {
                throw new ArgumentException($"Could not find the '{name}' keyword, although it was used previously. It might indicate an internal error.");
            }
            // We ignore the return value and the result. The arguments will match anyway.
            KeywordManager.TryExecuteKeyword(name, keywords, arguments, out var _);
        }

        public void Shutdown()
        {
            server.Shutdown();
        }

        private readonly HttpServer server;
        private readonly KeywordManager keywordManager;
    }
}
