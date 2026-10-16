//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    internal class HttpServer : IDisposable
    {
        public HttpServer(XmlRpcServer processor)
        {
            xmlRpcServer = processor;
            listenerThread = new Thread(Runner)
            {
                Name = "Robot Framework listener thread",
                IsBackground = true
            };
        }

        public void Shutdown()
        {
            quit = true;
            if(Thread.CurrentThread != listenerThread)
            {
                listener?.Close();
                listenerThread.Join();
            }
        }

        public void Dispose()
        {
            xmlRpcServer.Dispose();
        }

        // port == 0 is special as it means "select any available port"
        public void Run(int port)
        {
            var selectAnyPort = (port == 0);
            // range 49152-65535 as suggested in https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.txt for Private Ports
            var minPort = selectAnyPort ? 49152 : port;
            var maxPort = selectAnyPort ? 65535 : port;

            if(!TryStartListener(out listener, out var actualPort, minPort, maxPort))
            {
                Logger.Log(LogLevel.Error, "Could not start the HTTP server on {0}", selectAnyPort ? "any port" : $"port {port}");
                return;
            }

            if(!TryCreatePortFile(actualPort))
            {
                return;
            }

            Logger.Log(LogLevel.Info, "Robot Framework remote server is listening on port {0}", actualPort);

            listenerThread.Start();
            listenerThread.Join();
        }

        public XmlRpcServer Processor { get { return xmlRpcServer; } }

        private bool TryCreatePortFile(int actualPort)
        {
            if(!TemporaryFilesManager.Instance.TryCreateFile(RobotPortFile, out var file))
            {
                Logger.Log(LogLevel.Error, "Could not create port file");
                return false;
            }

            try
            {
                File.WriteAllText(file, actualPort.ToString());
            }
            catch(Exception ex)
            {
                Logger.Log(LogLevel.Error, "Could not create port file: {0}", ex.Message);
                return false;
            }

            return true;
        }

        private bool TryStartListener(out HttpListener listener, out int port, int minPort, int maxPort)
        {
            for(port = minPort; port <= maxPort; port++)
            {
                listener = new HttpListener();
                if(RuntimeInfo.IsWindows())
                {
                    listener.Prefixes.Add($"http://localhost:{port}/");
                }
                else
                {
                    listener.Prefixes.Add($"http://*:{port}/");
                }
                try
                {
                    listener.Start();
                    return true;
                }
                catch(SocketException)
                {
                    listener.Close();
                    continue;
                }
                catch(HttpListenerException)
                {
                    listener.Close();
                    continue;
                }
            }

            listener = null;
            return false;
        }

        private void Runner()
        {
            while(!quit)
            {
                try
                {
                    var context = listener.GetContext();
                    xmlRpcServer.ProcessRequest(context);
                }
                catch(ObjectDisposedException)
                {
                    break;
                }
            }
            Logger.Log(LogLevel.Info, "Robot Framework remote servers listener thread stopped");
        }

        private volatile bool quit;
        private HttpListener listener;
        private readonly Thread listenerThread;
        private readonly XmlRpcServer xmlRpcServer;

        private const string RobotPortFile = "robot_port";
    }
}
