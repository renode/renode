//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
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
            if(!ShouldBeLogged(entry))
            {
                return;
            }
            
            lock(messages)
            {
                messages.Add($"{entry.ObjectName}: {entry.Message}");
            }
            lineEvent.Set();
        }

        public string WaitForEntry(string pattern, out IEnumerable<string> bufferedMessages, float? timeout = null, bool keep = false, bool treatAsRegex = false)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            var regex = treatAsRegex ? new Regex(pattern) : null;
            var predicate = treatAsRegex ? (Predicate<string>)(x => regex.IsMatch(x)) : (Predicate<string>)(x => x.Contains(pattern));

            if(timeout.HasValue && timeout.Value == 0)
            {
                return FlushAndCheckLocked(emulation, predicate, keep, out bufferedMessages);
            }
            
            var timeoutEvent = emulation.MasterTimeSource.EnqueueTimeoutEvent((ulong)((timeout ?? defaultTimeout) * 1000));
            do
            {
                if(TryFind(predicate, keep, out var result))
                {
                    bufferedMessages = null;
                    return result;
                }

                WaitHandle.WaitAny(new [] { timeoutEvent.WaitHandle, lineEvent });
            }
            while(!timeoutEvent.IsTriggered);
            
            // let's check for the last time and lock any incoming messages
            return FlushAndCheckLocked(emulation, predicate, keep, out bufferedMessages);
        }

        private string FlushAndCheckLocked(Emulation emulation, Predicate<string> predicate, bool keep, out IEnumerable<string> bufferedMessages)
        {
            emulation.CurrentLogger.Flush();
            lock(messages)
            {
                if(TryFind(predicate, keep, out var result))
                {
                    bufferedMessages = null;
                    return result;
                }

                bufferedMessages = messages.ToList();
                return null;
            }
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
