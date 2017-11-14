
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
            var keywordManager = new KeywordManager();
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
                    Emulator.FinishExecutionAsMainThread();
                }
            });
        }

        public void ExecuteKeyword(string name, string[] arguments)
        {
            server.Processor.RunKeyword(name, arguments);
        }

        public void Shutdown()
        {
            server.Shutdown();
        }

        private readonly HttpServer server;
    }
}