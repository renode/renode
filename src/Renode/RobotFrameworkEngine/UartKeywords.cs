//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using Antmicro.Renode.Core;
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

        [RobotFrameworkKeyword]
        public void SetDefaultUartTimeout(float timeout)
        {
            globalTimeout = timeout;
        }

        [RobotFrameworkKeyword]
        public string GetTerminalTesterReport(int? testerId = null)
        {
            return GetTesterOrThrowException(testerId).GetReport();
        }

        [RobotFrameworkKeyword]
        public int CreateTerminalTester(string uart, float? timeout = null, string machine = null, string endLineOption = null)
        {
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
        public TerminalTesterResult WaitForPromptOnUart(string prompt, int? testerId = null, float? timeout = null, bool treatAsRegex = false)
        {
            return WaitForLineOnUart(prompt, timeout, testerId, treatAsRegex, true);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForLineOnUart(string content, float? timeout = null, int? testerId = null, bool treatAsRegex = false, bool includeUnfinishedLine = false)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine);
            if(result == null)
            {
                OperationFail(tester);
            }
            return result;
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForNextLineOnUart(float? timeout = null, int? testerId = null)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            var result = tester.NextLine(timeInterval);
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
        public TerminalTesterResult WriteLineToUart(string content = "", int? testerId = null, bool waitForEcho = true)
        {
            var tester = GetTesterOrThrowException(testerId);
            tester.WriteLine(content);
            if(waitForEcho && tester.WaitFor(content, includeUnfinishedLine: true) == null)
            {
                OperationFail(tester);
            }
            return new TerminalTesterResult(string.Empty, 0);
        }

        [RobotFrameworkKeyword]
        public void TestIfUartIsIdle(float timeout, int? testerId = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            var result = tester.IsIdle(TimeInterval.FromSeconds(timeout));
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

        private float globalTimeout = 8;
    }
}
