//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Text;

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

        [RobotFrameworkKeyword]
        public void RegisterFailingUartString(string pattern, bool treatAsRegex = false, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).RegisterFailingString(pattern, treatAsRegex);
        }

        [RobotFrameworkKeyword]
        public void UnregisterFailingUartString(string pattern, bool treatAsRegex = false, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).UnregisterFailingString(pattern, treatAsRegex);
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public int CreateTerminalTester(string uart, float? timeout = null, string machine = null, string endLineOption = null,
            bool? defaultPauseEmulation = null, bool? defaultWaitForEcho = null, bool? defaultMatchNextLine = null, bool binaryMode = false)
        {
            this.defaultPauseEmulation = defaultPauseEmulation.GetValueOrDefault();
            this.defaultMatchNextLine = defaultMatchNextLine.GetValueOrDefault();
            this.defaultWaitForEcho = defaultWaitForEcho ?? true;

            return CreateNewTester(uartObject =>
            {
                var timeoutInSeconds = timeout ?? globalTimeout;

                TerminalTester tester;
                if(Enum.TryParse<EndLineOption>(endLineOption, out var result))
                {
                    tester = new TerminalTester(TimeInterval.FromSeconds(timeoutInSeconds), result, binaryMode: binaryMode);
                }
                else
                {
                    tester = new TerminalTester(TimeInterval.FromSeconds(timeoutInSeconds), binaryMode: binaryMode);
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
            return DoTest(timeout, testerId, (tester, timeInterval) =>
            {
                var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine,
                pauseEmulation ?? defaultPauseEmulation, matchNextLine ?? defaultMatchNextLine);
                if(result?.IsFailingString == true)
                {
                    throw new InvalidOperationException($"Terminal tester failed!\n\nTest failing entry has been found on UART:\n{result.Line}");
                }
                return result;
            });
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForLinesOnUart(string[] content, float? timeout = null, int? testerId = null, bool treatAsRegex = false,
            bool includeUnfinishedLine = false, bool? pauseEmulation = null, bool? matchFromNextLine = null)
        {
            return DoTest(timeout, testerId, (tester, timeInterval) =>
            {
                var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine,
                    pauseEmulation ?? defaultPauseEmulation, matchFromNextLine ?? defaultMatchNextLine);
                if(result?.IsFailingString == true)
                {
                    throw new InvalidOperationException($"Terminal tester failed!\n\nTest failing entry has been found on UART:\n{result.Line}");
                }
                return result;
            });
        }

        [RobotFrameworkKeyword]
        public BinaryTerminalTesterResult WaitForBytesOnUart(string content, float? timeout = null, int? testerId = null, bool treatAsRegex = false,
            bool? pauseEmulation = null, bool? matchStart = false)
        {
            return DoTest(timeout, testerId, (tester, timeInterval) =>
            {
                var result = tester.WaitFor(content, timeInterval, treatAsRegex, includeUnfinishedLine: true,
                    pauseEmulation ?? defaultPauseEmulation, matchStart ?? defaultMatchNextLine);
                if(result?.IsFailingString == true)
                {
                    throw new InvalidOperationException($"Terminal tester failed!\n\nTest failing entry has been found on UART:\n{result.Line}");
                }
                return result != null ? new BinaryTerminalTesterResult(result) : null;
            }, expectBinaryModeTester: true);
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
                throw new InvalidOperationException($"Terminal tester failed!\n\nUnexpected entry has been found on UART#:\n{result.Line}");
            }
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WaitForNextLineOnUart(float? timeout = null, int? testerId = null, bool? pauseEmulation = null)
        {
            return DoTest(timeout, testerId, (tester, timeInterval) =>
            {
                return tester.NextLine(timeInterval, pauseEmulation ?? defaultPauseEmulation);
            });
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
        public TerminalTesterResult WriteLineToUart(string content = "", int? testerId = null, bool? waitForEcho = null, bool? pauseEmulation = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            tester.WriteLine(content);
            if((waitForEcho ?? defaultWaitForEcho) && tester.WaitFor(content, includeUnfinishedLine: true, pauseEmulation: pauseEmulation ?? defaultPauseEmulation) == null)
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

        private T DoTest<T>(float? timeout, int? testerId, Func<TerminalTester, TimeInterval?, T> test, bool expectBinaryModeTester = false)
        {
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }

            var tester = GetTesterOrThrowException(testerId);
            if(tester.BinaryMode != expectBinaryModeTester)
            {
                var waitedThing = expectBinaryModeTester ? "bytes" : "text";
                var testerMode = tester.BinaryMode ? "binary" : "text";
                throw new InvalidOperationException($"Attempt to wait for {waitedThing} on a tester configured in {testerMode} mode. " +
                        $"Please set binaryMode={!tester.BinaryMode} when creating the tester.");
            }

            var result = test(tester, timeInterval);
            if(result == null)
            {
                OperationFail(tester);
            }
            return result;
        }

        private void OperationFail(TerminalTester tester)
        {
            throw new InvalidOperationException($"Terminal tester failed!\n\nFull report:\n{tester.GetReport()}");
        }

        private bool defaultPauseEmulation;
        private bool defaultWaitForEcho;
        private bool defaultMatchNextLine;
        private float globalTimeout = 8;

        // The 'binary strings' used internally are not safe to pass through XML-RPC, probably due to special character escaping
        // issues. See https://github.com/antmicro/renode/commit/7739c14c6275058e71da30997c8e0f80144ed81c
        // and Misc.StripNonSafeCharacters. Here we represent the results as byte[] which get represented as base64 in the
        // XML-RPC body and <class 'bytes'> in the Python client.
        public class BinaryTerminalTesterResult
        {
            public BinaryTerminalTesterResult(TerminalTesterResult result)
            {
                this.Content = Encode(result.Line) ?? Array.Empty<byte>();
                this.Timestamp = Timestamp;
                this.Groups = result.Groups.Select(Encode).ToArray();
            }

            public byte[] Content { get; }

            public double Timestamp { get; }

            public byte[][] Groups { get; }

            private byte[] Encode(string str)
            {
                if(str == null)
                {
                    return null;
                }
                // Encode using the Latin1 encoding, which maps each character directly to its
                // corresponding byte value (that is, "\x00\x80\xff" becomes { 0x00, 0x80, 0xff }).
                return Encoding.GetEncoding("iso-8859-1").GetBytes(str);
            }
        }
    }
}