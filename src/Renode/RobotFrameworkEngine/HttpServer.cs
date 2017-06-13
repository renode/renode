//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Net;
using System.Threading;
using Emul8.Logging;

namespace Antmicro.Renode.RobotFramework
{
    internal class HttpServer : IDisposable
    {
        public HttpServer(XmlRpcServer processor)
        {
            listener = new HttpListener();
            xmlRpcServer = processor;
            listenerThread = new Thread(Runner)
            {
                Name = "Robot Framework listener thread",
                IsBackground = true
            };
        }

        public void Run(int port)
        {
            Logger.Log(LogLevel.Info, "Robot Framework remote server is listening on port {0}", port);
            listener.Prefixes.Add(string.Format("http://*:{0}/", port));
            listenerThread.Start();
            listenerThread.Join();
        }

        public void Shutdown()
        {
            quit = true;
            if(Thread.CurrentThread != listenerThread)
            {
                listener.Close();
                listenerThread.Join();
            }
        }

        public void Dispose()
        {
            xmlRpcServer.Dispose();
        }

        public XmlRpcServer Processor { get { return xmlRpcServer; } }

        private void Runner()
        {
            listener.Start();
            while(!quit)
            {
                var context = listener.GetContext();
                xmlRpcServer.ProcessRequest(context);
            }
            Logger.Log(LogLevel.Info, "Robot Framework remote servers listener thread stopped");
        }

        private bool quit;
        private readonly HttpListener listener;
        private readonly Thread listenerThread;
        private readonly XmlRpcServer xmlRpcServer;
    }
}

