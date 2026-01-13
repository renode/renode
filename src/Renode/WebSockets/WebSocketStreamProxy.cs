//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.WebSockets
{
    public class WebSocketStreamProxy : IDisposable
    {
        public WebSocketStreamProxy()
        {
            sync = new object();
            processes = new Dictionary<WebSocketConnection, ProxyProcess>();
            websocketServer = new WebSocketServerProvider("/run", true);
            websocketServer.NewConnection += ClientConnectedEventHandler;
            websocketServer.Disconnected += ClientDisconnectEventHandler;
        }

        public void Start()
        {
            websocketServer.Start();
        }

        public void Dispose()
        {
            lock(sync)
            {
                foreach(var proc in processes)
                {
                    proc.Value.Dispose();
                }

                processes.Clear();
                websocketServer.Dispose();
            }
        }

        public void ClientConnectedEventHandler(WebSocketConnection sender, List<string> extraArgs)
        {
            lock(sync)
            {
                string program = defaultProgram;
                if(extraArgs.Count == 1)
                {
                    program = extraArgs[0];
                }

                var newProcess = new ProxyProcess(program, gdbArgs, sender);

                if(newProcess.Start())
                {
                    processes.Add(sender, newProcess);
                }
                else
                {
                    // Unable to start process - close requesting connection
                    sender.Dispose();
                }
            }
        }

        private void ClientDisconnectEventHandler(WebSocketConnection sender)
        {
            lock(sync)
            {
                if(!processes.TryGetValue(sender, out var proc))
                {
                    return;
                }

                proc.Dispose();
                processes.Remove(sender);
            }
        }

        private static readonly List<string> gdbArgs = new List<string> { "--interpreter=mi", "--quiet" };
        private static readonly string defaultProgram = "gdb-multiarch";

        private readonly object sync;
        private readonly Dictionary<WebSocketConnection, ProxyProcess> processes;
        private readonly WebSocketServerProvider websocketServer;

        private class ProxyProcess : IDisposable
        {
            public ProxyProcess(string name, List<string> args, WebSocketConnection client)
            {
                this.args = args;
                isRunning = false;
                WebsocketClient = client;
                sendQueue = new ConcurrentQueue<byte[]>();
                WebsocketClient.DataBlockReceived += DataBlockReceivedEventHandler;
                cancellationToken = new CancellationTokenSource();
                enqueuedEvent = new AutoResetEvent(false);
                programName = name;
            }

            public bool Start()
            {
                isRunning = TrySpawnProcess(this.args, out this.process);
                return isRunning;
            }

            public void Dispose()
            {
                if(!isRunning)
                {
                    return;
                }

                isRunning = false;
                cancellationToken.Cancel();

                readOutputTask.Wait();
                writeInputTask.Wait();

                stdin.Dispose();
                stdout.Dispose();

                process.Kill();
                process.WaitForExit();
                process.Dispose();
            }

            public readonly WebSocketConnection WebsocketClient;

            private bool TrySpawnProcess(List<string> args, out Process process)
            {
                process = null;

                var processOptions = new ProcessStartInfo
                {
                    FileName = programName,
                    CreateNoWindow = true,
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                };

                foreach(var arg in args)
                {
                    processOptions.ArgumentList.Add(arg);
                }

                var newProcess = new Process
                {
                    StartInfo = processOptions
                };

                try
                {
                    if(!newProcess.Start())
                    {
                        return false;
                    }
                }
                catch(Exception)
                {
                    return false;
                }

                Logger.Log(LogLevel.Info, "Created new process: {0}", programName);

                stdout = newProcess.StandardOutput.BaseStream;
                stdin = newProcess.StandardInput.BaseStream;

                readOutputTask = Task.Run(ReadOutputAsync);
                writeInputTask = Task.Run(WriteInputAsync);

                process = newProcess;
                return true;
            }

            private void DataBlockReceivedEventHandler(byte[] data)
            {
                sendQueue.Enqueue(data);
                enqueuedEvent.Set();
            }

            private async Task ReadOutputAsync()
            {
                var token = cancellationToken.Token;
                var buffer = new byte[BufferSize];
                int readCount = 0;

                while((readCount = await stdout.ReadAsync(buffer, 0, BufferSize, token)) != 0)
                {
                    var fixedBuffer = buffer.Take(readCount).ToArray();
                    WebsocketClient.Send(fixedBuffer);
                }

                if(!cancellationToken.IsCancellationRequested)
                {
                    cancellationToken.Cancel();
                }
            }

            private async Task WriteInputAsync()
            {
                var token = cancellationToken.Token;

                while(!cancellationToken.IsCancellationRequested)
                {
                    if(WaitHandle.WaitAny(new[] { enqueuedEvent, token.WaitHandle }) == 1)
                    {
                        break;
                    }

                    enqueuedEvent.Reset();

                    while(sendQueue.TryDequeue(out var data))
                    {
                        await stdin.WriteAsync(data, token);
                        await stdin.FlushAsync(token);
                    }
                }
            }

            private Stream stdout;
            private Stream stdin;

            private Task readOutputTask;
            private Task writeInputTask;

            private Process process;
            private bool isRunning;

            private readonly string programName;
            private readonly List<string> args;
            private readonly AutoResetEvent enqueuedEvent;
            private readonly CancellationTokenSource cancellationToken;
            private readonly ConcurrentQueue<byte[]> sendQueue;

            private const int BufferSize = 1024;
        }
    }
}
