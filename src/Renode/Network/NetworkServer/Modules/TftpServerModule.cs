//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.IO;
using System.Net;
using System.Collections.Generic;
using System.Threading.Tasks;

using libtftp;
using PacketDotNet;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Exceptions;

namespace Antmicro.Renode.Network
{
    public static class TftpServerExtensions
    {
        public static void StartTFTP(this NetworkServer server, int port, string name = "tftp")
        {
            var module = new TftpServerModule(port);
            if(!server.RegisterModule(module, port, name))
            {
                throw new RecoverableException($"Couldn't start TFTP server on port {port}. See log for details");
            }
        }
    }

    public class TftpServerModule : IUdpServerModule, IEmulationElement
    {
        public TftpServerModule(int port)
        {
            Port = port;

            callbacks = new Dictionary<IPEndPoint, Action<IPEndPoint, UdpPacket>>();
            files = new Dictionary<string, string>();
            directories = new List<string>();
            
            server = TftpServer.Instance;

            server.Log = HandleLog;
            server.DataReady = HandleResponse;

            server.GetStream += HandleStream;

            this.Log(LogLevel.Info, "TFTP server started at port {0}", Port);
        }

        public void ServeFile(string path, string name = null)
        {
            files.Add(name ?? Path.GetFileName(path), path);
        }

        public void ServeDirectory(string directory)
        {
            directories.Add(directory);
        }

        public void HandleUdp(IPEndPoint source, UdpPacket packet, Action<IPEndPoint, UdpPacket> callback)
        {
            callbacks[source] = callback;
            server.OnUdpData(source, packet.PayloadData);
        }

        public int Port { get; }

        private void HandleLog(object src, TftpLogEventArgs args)
        {
            LogLevel logLevel;

            switch(args.Severity)
            {
                case ETftpLogSeverity.Debug:
                    logLevel = LogLevel.Debug;
                    break;

                case ETftpLogSeverity.Informational:
                case ETftpLogSeverity.Notice:
                    logLevel = LogLevel.Info;
                    break;

                case ETftpLogSeverity.Warning:
                    logLevel = LogLevel.Warning;
                    break;

                case ETftpLogSeverity.Error:
                case ETftpLogSeverity.Critical:
                case ETftpLogSeverity.Alert:
                case ETftpLogSeverity.Emergency:
                    logLevel = LogLevel.Error;
                    break;

                default:
                    throw new ArgumentException($"Unhandled log severity: {args.Severity}");
            }

            this.Log(logLevel, args.Message);
        }

        private void HandleResponse(IPEndPoint source, byte[] buffer, int count)
        {
            var response = new UdpPacket((ushort)Port, (ushort)source.Port);

            if(count == buffer.Length)
            {
                response.PayloadData = buffer;
            }
            else
            {
                var newBuffer = new byte[count];
                Array.Copy(buffer, 0, newBuffer, 0, count);
                response.PayloadData = newBuffer;
            }

            callbacks[source](source, response);
        }

        private async Task HandleStream(object caller, TftpGetStreamEventArgs args)
        {
            this.Log(LogLevel.Noisy, "Searching for file {0}", args.Filename);

            var path = await Task.Run(() => FindFile(args.Filename));
            if(path == null)
            {
                this.Log(LogLevel.Warning, "Asked for {0} file, but it does not exist", args.Filename);
                return;
            }

            try
            {
                using (var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read))
                {
                    var buffer = new byte[stream.Length];
                    await stream.ReadAsync(buffer, 0, (int)stream.Length);
                    args.Result = new MemoryStream(buffer);
                }
            }
            catch (Exception e)
            {
                this.Log(LogLevel.Warning, "There was an error when reading {0} file: {1}", path, e.Message);
            }
}

            private string FindFile(string filename)
            {
                // first check list of files
                if(!files.TryGetValue(filename, out var result))
                {
                    // if not found, scan all the directories
                    foreach(var dir in directories)
                    {
                        foreach(var file in Directory.GetFiles(dir))
                        {
                            if(file.Substring(dir.Length + 1) == filename)
                            {
                                result = file;
                                break;
                            }
                        }
                    }
                }
                return result;
            }

        private readonly Dictionary<string, string> files;
        private readonly List<string> directories;

        private readonly Dictionary<IPEndPoint, Action<IPEndPoint, UdpPacket>> callbacks;
        private readonly TftpServer server;
    }
}
