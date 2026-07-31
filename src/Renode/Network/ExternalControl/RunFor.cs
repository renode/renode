//
// Copyright (c) 2010-2026 Antmicro
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

        public override MessagePayload Invoke(List<byte> data)
        {
            if(disposed)
            {
                return MessagePayload.Error(Identifier, "Command is unavailable");
            }

            if(data.Count != 8)
            {
                return MessagePayload.Error(Identifier, "Expected 8 bytes of payload");
            }

            if(cancellationToken != null)
            {
                return MessagePayload.Error(Identifier, "One RunFor command can be running at any given time");
            }

            cancellationToken = new CancellationTokenSource();
            exception = null;
            success = false;

            var nanoseconds = BitConverter.ToUInt64(data.ToArray(), 0);
            var interval = TimeInterval.FromNanoseconds(nanoseconds);

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
                return MessagePayload.Success(Identifier);
            }
            return MessagePayload.Error(Identifier, "RunFor was interrupted");
        }

        public override Command Identifier => Command.RunFor;

        private bool success;
        private Exception exception;
        private CancellationTokenSource cancellationToken;
        private bool disposed;
    }
}
