//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Text.RegularExpressions;
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

        public string WaitForEntry(string pattern, float? timeout = null, bool keep = false, bool treatAsRegex = false)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            var regex = treatAsRegex ? new Regex(pattern) : null;
            var predicate = treatAsRegex ? (Predicate<string>)(x => regex.IsMatch(x)) : (Predicate<string>)(x => x.Contains(pattern));
            
            if(timeout.HasValue && timeout.Value == 0)
            {
                emulation.CurrentLogger.Flush();
                
                if(TryFind(predicate, keep, out var result))
                {
                    return result;
                }
                return null;
            }
            
            var timeoutEvent = emulation.MasterTimeSource.EnqueueTimeoutEvent((ulong)((timeout ?? defaultTimeout) * 1000));
            do
            {
                if(TryFind(predicate, keep, out var result))
                {
                    return result;
                }

                WaitHandle.WaitAny(new [] { timeoutEvent.WaitHandle, lineEvent });
            }
            while(!timeoutEvent.IsTriggered);

            return null;
        }

        private bool TryFind(Predicate<string> predicate, bool keep, out string result)
        {
            lock(messages)
            {
                var idx = messages.FindIndex(predicate);
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
