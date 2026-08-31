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
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class TimeElapsedCallbackCommand : BaseCommand, IDisposable
    {
        public TimeElapsedCallbackCommand(ExternalControlSocket parent)
            : base(parent)
        {
        }

        public void Dispose()
        {
            lock(syncedStateCallbacks)
            {
                if(syncedStateActionId.HasValue)
                {
                    EmulationManager.Instance.CurrentEmulation.MasterTimeSource.CancelActionToExecuteInSyncedState(syncedStateActionId.Value);
                }
            }
        }

        public void RegisterExternalCallback(Action<TimeStamp> callback)
        {
            int id;
            lock(externalCallbacks)
            {
                id = externalCallbacks.Count;
                externalCallbacks.Add(callback);
            }

            var response = parent.SendRequest(new MessagePayload(Command.TimeElapsedCallback, CommandType.Request, BitConverter.GetBytes(id)));
            response.LogOnError(Identifier, parent);
        }

        public override MessagePayload Invoke(MessagePayload payload)
        {
            return payload.Type switch
            {
                CommandType.Request => HandleRequest(payload.Data),
                CommandType.EventRequest => HandleEventRequest(payload.Data),
                _ => MessagePayload.Error(Identifier, "Invalid command type"),
            };
        }

        public override Command Identifier => Command.TimeElapsedCallback;

        private MessagePayload HandleRequest(byte[] data)
        {
            if(data.Length != sizeof(int))
            {
                return MessagePayload.Error(Identifier, $"Invalid data size, expected: {sizeof(int)} but got: {data.Length} bytes");
            }

            var callbackIdentifier = BitConverter.ToInt32(data);

            lock(syncedStateCallbacks)
            {
                if(!syncedStateActionId.HasValue)
                {
                    SendEventInNearestSyncedState();
                }
                syncedStateCallbacks.Add(callbackIdentifier);
            }

            parent.Log(LogLevel.Debug, "Registered time elapsed callback");

            return MessagePayload.Success(Identifier);
        }

        private MessagePayload HandleEventRequest(byte[] data)
        {
            TimeElapsedEvent timeEvent;
            try
            {
                timeEvent = data.ToStruct<TimeElapsedEvent>();
            }
            catch
            {
                return MessagePayload.Error(Identifier, "Can't decode request");
            }
            var timestamp = new TimeStamp(TimeInterval.FromNanoseconds(timeEvent.Nanoseconds), EmulationManager.ExternalWorld);
            parent.Log(LogLevel.Debug, "Received time elapse event, timestamp: {0}", timestamp);

            lock(externalCallbacks)
            {
                foreach(var callback in externalCallbacks)
                {
                    callback.Invoke(timestamp);
                }
            }

            return MessagePayload.Success(Identifier);
        }

        private void SendEventInNearestSyncedState()
        {
            syncedStateActionId = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ExecuteInNearestSyncedState(OnSyncedState);
        }

        private void OnSyncedState(TimeStamp timestamp)
        {
            try
            {
                var nanoseconds = timestamp.TimeElapsed.TotalNanoseconds;
                lock(syncedStateCallbacks)
                {
                    foreach(var callbackIdentifier in syncedStateCallbacks)
                    {
                        var response = parent.SendRequest(MessagePayload.FromStruct(Identifier, CommandType.EventRequest, new TimeElapsedEvent(callbackIdentifier, nanoseconds)));
                        response.LogOnError(Identifier, parent);
                    }

                    SendEventInNearestSyncedState();
                }
            }
            catch(ServerDisposedException)
            {
                parent.WarningLog("{0} got invoked on a disposed {1}", nameof(TimeElapsedCallbackCommand), nameof(ExternalControlSocket));
            }
        }

        private ulong? syncedStateActionId;
        private readonly List<int> syncedStateCallbacks = new List<int>();
        private readonly List<Action<TimeStamp>> externalCallbacks = new();

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private readonly record struct TimeElapsedEvent(int CallbackIdentifier, ulong Nanoseconds);
    }
}
