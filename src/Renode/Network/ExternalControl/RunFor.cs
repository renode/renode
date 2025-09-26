//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class RunFor : BaseCommand, IDisposable
    {
        public RunFor(ExternalControlServer parent)
            : base(parent)
        {
        }

        public void Dispose()
        {
            if(cancellationToken != null)
            {
                parent.Log(LogLevel.Warning, "RunFor disposed while running");
            }
            cancellationToken?.Cancel();
            cancellationToken = null;
            disposed = true;
        }

        public override Response Invoke(List<byte> data)
        {
            if(disposed)
            {
                return Response.CommandFailed(Identifier, "Command is unavailable");
            }

            if(data.Count != 8)
            {
                return Response.CommandFailed(Identifier, "Expected 8 bytes of payload");
            }

            if(cancellationToken != null)
            {
                return Response.CommandFailed(Identifier, "One RunFor command can be running at any given time");
            }

            cancellationToken = new CancellationTokenSource();
            exception = null;
            success = false;

            var microseconds = BitConverter.ToUInt64(data.ToArray(), 0);
            var interval = TimeInterval.FromMicroseconds(microseconds);

            var thread = new Thread(() =>
            {
                try
                {
                    parent.Log(LogLevel.Info, "Executing RunFor({0}) command", interval);
                    EmulationManager.Instance.CurrentEmulation.RunFor(interval);

                    if(cancellationToken.IsCancellationRequested)
                    {
                        return;
                    }

                    success = true;
                }
                catch(Exception e)
                {
                    exception = e;
                }
                cancellationToken?.Cancel();
            })
            {
                IsBackground = true,
                Name = GetType().Name
            };

            thread.Start();
            cancellationToken.Token.WaitHandle.WaitOne();
            cancellationToken = null;

            if(exception != null)
            {
                throw exception;
            }

            if(success)
            {
                return Response.Success(Identifier);
            }
            return Response.CommandFailed(Identifier, "RunFor was interrupted");
        }

        public override Command Identifier => Command.RunFor;

        public override byte Version => 0x0;

        private bool success;
        private Exception exception;
        private CancellationTokenSource cancellationToken;
        private bool disposed;
    }
}