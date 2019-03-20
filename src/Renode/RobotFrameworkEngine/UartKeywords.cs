//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
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
        public int CreateTerminalTester(string uart, string prompt = null, int timeout = 30, string machine = null)
        {
            return CreateNewTester(uartObject => 
            {
                var tester = new TerminalTester(TimeInterval.FromSeconds((uint)timeout), prompt);
                tester.Terminal.AttachTo(uartObject);
                return tester;
            }, uart, machine);
        }

        [RobotFrameworkKeyword]
        public void SetNewPromptForUart(string prompt, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).NowPromptIs(prompt);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForLineOnUart(string content, uint? timeout = null, int? testerId = null, bool treatAsRegex = false)
        {
            var groups = new string[0];
            GetTesterOrThrowException(testerId).WaitUntilLineFunc(
                x =>
                {
                    if(!treatAsRegex)
                    {
                        return x.Contains(content);
                    }
                    var match = Regex.Match(x, content);
                    groups = match.Success ? match.Groups.Cast<Group>().Skip(1).Select(y => y.Value).ToArray() : new string[0];
                    return match.Success;
                },
                out string line,
                out var time,
                timeout == null ? (TimeInterval?)null : TimeInterval.FromSeconds(timeout.Value)
            );
            return new TerminalTesterResult(line, time.TotalMilliseconds, groups);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForNextLineOnUart(uint? timeout = null, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).WaitUntilLineExpr(
                x => true,
                out string line,
                out var time,
                timeout == null ? (TimeInterval?)null : TimeInterval.FromSeconds(timeout.Value)
            );
            return new TerminalTesterResult(line, time.TotalMilliseconds);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForPromptOnUart(string prompt = null, int? testerId = null, uint? timeout = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            string previousPrompt = null;
            if(prompt != null)
            {
                previousPrompt = tester.Terminal.Prompt;
                tester.Terminal.Prompt = prompt;
            }

            var result = new TerminalTesterResult(
                tester.ReadToPrompt(out var time, timeout == null ? (TimeInterval?)null : TimeInterval.FromSeconds(timeout.Value)),
                time.TotalMilliseconds
            );

            if(previousPrompt != null)
            {
                tester.Terminal.Prompt = previousPrompt;
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
            return new TerminalTesterResult(null, 0);
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WriteLineToUart(string content = "", int? testerId = null, bool waitForEcho = true)
        {
            GetTesterOrThrowException(testerId).WriteLine(out var time, content, !waitForEcho);
            return new TerminalTesterResult(content, time.TotalMilliseconds);
        }

        [RobotFrameworkKeyword]
        public void TestIfUartIsIdle(uint timeInSeconds, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).CheckIfUartIsIdle(TimeInterval.FromSeconds(timeInSeconds));
        }

        public struct TerminalTesterResult
        {
            public TerminalTesterResult(string line, double timestamp, string[] groups = null)
            {
                this.line = line == null ? string.Empty : line.StripNonSafeCharacters();
                this.timestamp = timestamp;
                this.groups = groups ?? new string[0];
            }

            public string line;
            public string[] groups;
            public double timestamp;
        }
    }
}
