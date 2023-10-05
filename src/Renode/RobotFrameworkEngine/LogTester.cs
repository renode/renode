//
// Copyright (c) 2010-2023 Antmicro
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
            // we need to use synchronous logging in order to pause the emulation precisely
            EmulationManager.Instance.CurrentEmulation.CurrentLogger.SynchronousLogging = true;

            this.defaultTimeout = virtualSecondsTimeout;
            messages = new List<LogEntry>();
            predicateEvent = new AutoResetEvent(false);
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
                messages.Add(entry);

                if(predicate == null)
                {
                    // we are currently not waiting for any message
                    return;
                }

                if(!predicate(entry))
                {
                    // not found anything interesting
                    return;
                }

                if(pauseEmulation)
                {
                    if(!EmulationManager.Instance.CurrentEmulation.TryGetExecutionContext(out var machine, out var __))
                    {
                        // we are not on a CPU thread so we can issue a global pause
                        EmulationManager.Instance.CurrentEmulation.PauseAll();
                    }
                    else
                    {
                        // mind that we don't use precise pausing as there is no guarantee this code is being executed from a CPU thread with a pause guard
                        // it is still deterministic though
                        machine.PauseAndRequestEmulationPause(precise: false);
                    }
                    pauseEmulation = false;
                }

                predicate = null;
                predicateEvent.Set();
            }
        }

        public string WaitForEntry(string pattern, out IEnumerable<string> bufferedMessages, float? timeout = null, bool keep = false, bool treatAsRegex = false,
            bool pauseEmulation = false, LogLevel level = null)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            var regex = treatAsRegex ? new Regex(pattern) : null;
            var predicate = treatAsRegex ? (Predicate<LogEntry>)(x => regex.IsMatch(x.FullMessage)) : (x => x.FullMessage.Contains(pattern));
            if(level != null)
            {
                var innerPredicate = predicate;
                predicate = x => innerPredicate(x) && x.Type == level;
            }
            var effectiveTimeout = timeout ?? defaultTimeout;

            lock(messages)
            {
                var entry = FlushAndCheckLocked(emulation, predicate, keep, out bufferedMessages);
                if(entry != null || (effectiveTimeout == 0))
                {
                    return entry;
                }

                this.pauseEmulation = pauseEmulation;
                this.predicate = predicate;
                this.predicateEvent.Reset();
            }

            var emulationPausedEvent = emulation.GetStartedStateChangedEvent(false);
            if(!emulation.IsStarted)
            {
                emulation.StartAll();
            }

            var timeoutEvent = emulation.MasterTimeSource.EnqueueTimeoutEvent((ulong)(effectiveTimeout * 1000));
            var eventId = WaitHandle.WaitAny(new [] { timeoutEvent.WaitHandle, predicateEvent });

            if(eventId == 1)
            {
                // predicate event; we know the machine is paused, now we need to check for the rest of the emulation to stop
                if(pauseEmulation)
                {
                    emulationPausedEvent.WaitOne();
                }
            }

            // let's check for the last time and lock any incoming messages
            return FlushAndCheckLocked(emulation, predicate, keep, out bufferedMessages);
        }

        private string FlushAndCheckLocked(Emulation emulation, Predicate<LogEntry> predicate, bool keep, out IEnumerable<string> bufferedMessages)
        {
            emulation.CurrentLogger.Flush();
            lock(messages)
            {
                if(TryFind(predicate, keep, out var result))
                {
                    bufferedMessages = null;
                    return result.FullMessage;
                }

                bufferedMessages = messages.Select(x => x.FullMessage).ToList();
                return null;
            }
        }

        private bool TryFind(Predicate<LogEntry> predicate, bool keep, out LogEntry result)
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

        private bool pauseEmulation;
        private Predicate<LogEntry> predicate;

        private readonly AutoResetEvent predicateEvent;
        private readonly List<LogEntry> messages;
        private readonly float defaultTimeout;
    }
}
