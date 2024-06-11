//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.RobotFramework
{
    internal class UartKeywords : TestersProvider<TerminalTester, IUART>, IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void SetDefaultUartTimeout(float timeout)
        {
            globalTimeout = timeout;
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void SetDefaultTester(int? id)
        {
            SetDefaultTesterId(id);
        }

        [RobotFrameworkKeyword]
        public string GetTerminalTesterReport(int? testerId = null)
        {
            return GetTesterOrThrowException(testerId).GetReport();
        }

        [RobotFrameworkKeyword]
        public void ClearTerminalTesterReport(int? testerId = null)
        {
            GetTesterOrThrowException(testerId).ClearReport();
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public int CreateTerminalTester(string uart, float? timeout = null, string machine = null, string endLineOption = null, bool? defaultPauseEmulation = null, bool? defaultMatchNextLine = null)
        {
            this.defaultPauseEmulation = defaultPauseEmulation.GetValueOrDefault();
            this.defaultMatchNextLine = defaultMatchNextLine.GetValueOrDefault();

            return CreateNewTester(uartObject =>
            {
                var timeoutInSeconds = timeout ?? globalTimeout;

                TerminalTester tester;
                if(Enum.TryParse<EndLineOption>(endLineOption, out var result))
                {
                    tester = new TerminalTester(TimeInterval.FromSeconds(timeoutInSeconds), result);
                }
                else
                {
                    tester = new TerminalTester(TimeInterval.FromSeconds(timeoutInSeconds));
                }
                tester.AttachTo(uartObject);
                return tester;
            }, uart, machine);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForPromptOnUart(string prompt, int? testerId = null, float? timeout = null, bool treatAsRegex = false,
            bool? pauseEmulation = null)
        {
            return WaitForLineOnUart(prompt, timeout, testerId, treatAsRegex, true, pauseEmulation);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForLineOnUart(string content, float? timeout = null, int? testerId = null, bool treatAsRegex = false,
            bool includeUnfinishedLine = false, bool? pauseEmulation = null, bool? matchNextLine = null)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine,
                pauseEmulation ?? defaultPauseEmulation, matchNextLine ?? defaultMatchNextLine);
            if(result == null)
            {
                OperationFail(tester);
            }
            return result;
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForLinesOnUart(string[] content, float? timeout = null, int? testerId = null, bool treatAsRegex = false,
            bool includeUnfinishedLine = false, bool? pauseEmulation = null, bool? matchFromNextLine = null)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine,
                pauseEmulation ?? defaultPauseEmulation, matchFromNextLine ?? defaultMatchNextLine);
            if(result == null)
            {
                OperationFail(tester);
            }
            return result;
        }

        [RobotFrameworkKeyword]
        public void ShouldNotBeOnUart(string content, float? timeout = null, int? testerId = null, bool treatAsRegex = false,
            bool includeUnfinishedLine = false)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine, false);
            if(result != null)
            {
                throw new InvalidOperationException($"Terminal tester failed!\n\nUnexpected entry has been found on UART#:\n{result.line}");
            }
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForNextLineOnUart(float? timeout = null, int? testerId = null, bool? pauseEmulation = null)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.NextLine(timeInterval, pauseEmulation ?? defaultPauseEmulation);
            if(result == null)
            {
                OperationFail(tester);
            }
            return result;
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult SendKeyToUart(byte c, int? testerId = null)
        {
            return WriteCharOnUart((char)c, testerId);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WriteCharOnUart(char c, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).Write(c.ToString());
            return new TerminalTesterResult(string.Empty, 0);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WriteToUart(string content, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).Write(content);
            return new TerminalTesterResult(string.Empty, 0);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WriteLineToUart(string content = "", int? testerId = null, bool waitForEcho = true, bool? pauseEmulation = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            tester.WriteLine(content);
            if(waitForEcho && tester.WaitFor(content, includeUnfinishedLine: true, pauseEmulation: pauseEmulation ?? defaultPauseEmulation) == null)
            {
                OperationFail(tester);
            }
            return new TerminalTesterResult(string.Empty, 0);
        }

        [RobotFrameworkKeyword]
        public void TestIfUartIsIdle(float timeout, int? testerId = null, bool? pauseEmulation = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            var result = tester.IsIdle(TimeInterval.FromSeconds(timeout), pauseEmulation ?? defaultPauseEmulation);
            if(!result)
            {
                OperationFail(tester);
            }
        }

        [RobotFrameworkKeyword]
        public void WriteCharDelay(float delay, int? testerId = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            tester.WriteCharDelay = TimeSpan.FromSeconds(delay);
        }

        private void OperationFail(TerminalTester tester)
        {
            throw new InvalidOperationException($"Terminal tester failed!\n\nFull report:\n{tester.GetReport()}");
        }

        private bool defaultPauseEmulation;
        private bool defaultMatchNextLine;
        private float globalTimeout = 8;
    }
}
