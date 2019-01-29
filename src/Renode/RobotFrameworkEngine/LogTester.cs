using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.RobotFramework
{
    public class LogTester : TextBackend
    {
        public LogTester(int defaultMillisecondsTimeout)
        {
            this.defaultMillisecondsTimeout = defaultMillisecondsTimeout;
            messages = new List<string>();
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
                Monitor.Pulse(messages);
            }
        }

        public string WaitForEntry(string pattern, int? millisecondsTimeout = null, bool keep = false)
        {
            lock(messages)
            {
                var timeoutLeft = millisecondsTimeout ?? defaultMillisecondsTimeout;
                var swatch = new Stopwatch();
                while(timeoutLeft > 0)
                {
                    var idx = messages.FindIndex(x => x.Contains(pattern));
                    if(idx != -1)
                    {
                        var result = messages[idx];
                        if(!keep)
                        {
                            messages.RemoveRange(0, idx + 1);
                        }
                        return result;
                    }

                    swatch.Restart();
                    Monitor.Wait(messages, timeoutLeft);
                    swatch.Stop();

                    timeoutLeft -= checked((int)swatch.ElapsedMilliseconds);
                }

                return null;
            }
        }

        private readonly List<string> messages;
        private readonly int defaultMillisecondsTimeout;
    }
}