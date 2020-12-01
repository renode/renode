using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Core;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    public class LogTester : TextBackend
    {
        public LogTester(float virtualSecondsTimeout)
        {
            this.defaultTimeout = virtualSecondsTimeout;
            messages = new List<string>();
            lineEvent = new AutoResetEvent(false);
        }

        public override void Dispose()
        {
            lock(messages)
            {
                messages.Clear();
            }
        }

        public override void Log(LogEntry entry)
        {
            lock(messages)
            {
                messages.Add(entry.Message);
            }
            lineEvent.Set();
        }

        public string WaitForEntry(string pattern, float? timeout = null, bool keep = false)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            var timeoutEvent = emulation.MasterTimeSource.EnqueueTimeoutEvent((ulong)((timeout ?? defaultTimeout) * 1000));
            do
            {
                if(TryFind(pattern, keep, out var result))
                {
                    return result;
                }

                WaitHandle.WaitAny(new [] { timeoutEvent.WaitHandle, lineEvent });
            }
            while(!timeoutEvent.IsTriggered);

            return null;
        }

        private bool TryFind(string pattern, bool keep, out string result)
        {
            lock(messages)
            {
                var idx = messages.FindIndex(x => x.Contains(pattern));
                if(idx != -1)
                {
                    result = messages[idx];
                    if(!keep)
                    {
                        messages.RemoveRange(0, idx + 1);
                    }
                    return true;
                }
            }

            result = null;
            return false;
        }

        private readonly AutoResetEvent lineEvent;
        private readonly List<string> messages;
        private readonly float defaultTimeout;
    }
}