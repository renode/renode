//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class TimeElapsedCallbackCommand : BaseCommand
    {
        public TimeElapsedCallbackCommand(ExternalControlServer parent)
            : base(parent)
        {
        }

        public override MessagePayload Invoke(List<byte> data)
        {
            if(data.Count != sizeof(uint))
            {
                return MessagePayload.Error(Identifier, $"Invalid data size, expected: {sizeof(uint)} but got: {data.Count} bytes");
            }

            var callbackIdentifier = BitConverter.ToInt32(CollectionsMarshal.AsSpan(data));

            lock(callbacks)
            {
                if(callbacks.Count == 0)
                {
                    RegisterCallback();
                }
                callbacks.Add(callbackIdentifier);
            }

            parent.Log(LogLevel.Debug, "Registered time elapsed callback");

            return MessagePayload.Success(Identifier);
        }

        public override Command Identifier => Command.TimeElapsedCallback;

        private void RegisterCallback()
        {
            EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ExecuteInNearestSyncedState(SendEvent);
        }

        private void SendEvent(TimeStamp timestamp)
        {
            try
            {
                var nanoseconds = timestamp.TimeElapsed.TotalNanoseconds;
                foreach(var callbackIdentifier in callbacks)
                {
                    var response = parent.SendRequest(MessagePayload.Event(Identifier, callbackIdentifier, new TimeElapsedEvent(nanoseconds)));
                    LogOnErrorResponse(response);
                }

                RegisterCallback();
            }
            catch(ServerDisposedException)
            {
                parent.WarningLog("{0} got invoked on a disposed {1}", nameof(TimeElapsedCallbackCommand), nameof(ExternalControlServer));
            }
        }

        private readonly List<int> callbacks = new List<int>();

        [StructLayout(LayoutKind.Sequential)]
        private readonly record struct TimeElapsedEvent(ulong Nanoseconds);
    }
}
