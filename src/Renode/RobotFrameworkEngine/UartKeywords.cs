//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.RobotFramework
{
    internal class UartKeywords : IRobotFrameworkKeywordProvider
    {
        public UartKeywords()
        {
            testers = new Dictionary<int, TerminalTester>();
            uartsWithTesters = new HashSet<IUART>();
            EmulationManager.Instance.EmulationChanged += () =>
            {
                lock(testers)
                {
                    testers.Clear();
                }
            };
        }

        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public int CreateTerminalTester(string uart, string prompt = null, int timeout = 30, string machine = null)
        {
            lock(testers)
            {
                Machine machineObject;
                if(machine == null)
                {
                    if(!EmulationManager.Instance.CurrentEmulation.Machines.Any())
                    {
                        throw new KeywordException("There is no machine in the emulation. Could not create tester for peripheral: {0}", uart);
                    }
                    machineObject = EmulationManager.Instance.CurrentEmulation.Machines.Count() == 1
                        ? EmulationManager.Instance.CurrentEmulation.Machines.First()
                        : null;
                    if(machineObject == null)
                    {
                        throw new KeywordException("No machine name provided. Don't know which one to choose. Available machines: [{0}]",
                            string.Join(", ", EmulationManager.Instance.CurrentEmulation.Machines.Select(x => EmulationManager.Instance.CurrentEmulation[x])));
                    }
                }
                else if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(machine, out machineObject))
                {
                    throw new KeywordException("Machine with name {0} not found. Available machines: [{1}]", machine,
                            string.Join(", ", EmulationManager.Instance.CurrentEmulation.Machines.Select(x => EmulationManager.Instance.CurrentEmulation[x])));
                }

                if(!machineObject.TryGetByName(uart, out IUART uartObject))
                {
                    throw new KeywordException("Peripheral for machine {0} not found or of wrong type: {1}", machine, uart);
                }
                if(uartsWithTesters.Contains(uartObject))
                {
                    throw new KeywordException("Terminal tester for peripheral {0} in machine {1} already exists", uart, machine);
                }

                var tester = new TerminalTester(TimeInterval.FromSeconds((uint)timeout), prompt);
                tester.Terminal.AttachTo(uartObject);
                uartsWithTesters.Add(uartObject);
                testers.Add(uartsWithTesters.Count, tester);
            }
            return uartsWithTesters.Count;
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
        public TerminalTesterResult WaitForPromptOnUart(int? testerId = null, uint? timeout = null)
        {
            return new TerminalTesterResult(
                GetTesterOrThrowException(testerId).ReadToPrompt(out var time, timeout == null ? (TimeInterval?)null : TimeInterval.FromSeconds(timeout.Value)),
                time.TotalMilliseconds
            );
        }

        [RobotFrameworkKeyword]
        public TerminalTesterResult WriteLineToUart(string content, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).WriteLine(out var time, content);
            return new TerminalTesterResult(content, time.TotalMilliseconds);
        }

        [RobotFrameworkKeyword]
        public void TestIfUartIsIdle(uint timeInSeconds, int? testerId = null)
        {
            GetTesterOrThrowException(testerId).CheckIfUartIsIdle(TimeInterval.FromSeconds(timeInSeconds));
        }

        private TerminalTester GetTesterOrThrowException(int? testerId)
        {
            lock(testers)
            {
                TerminalTester tester;
                if(testerId == null)
                {
                    if(testers.Count != 1)
                    {
                        throw new KeywordException("There are more than one terminal tester available - please specify ID of the desired tester.");
                    }
                    tester = testers.Single().Value;
                }
                else if(!testers.TryGetValue(testerId.Value, out tester))
                {
                    throw new KeywordException("Terminal tester for given ID={0} was not found. Did you forget to call `Create Terminal Tester`?", testerId);
                }
                return tester;
            }
        }

        public struct TerminalTesterResult
        {
            public TerminalTesterResult(string line, double timestamp, string[] groups = null)
            {
                this.line = line ?? string.Empty;
                this.timestamp = timestamp;
                this.groups = groups ?? new string[0];
            }

            public string line;
            public string[] groups;
            public double timestamp;
        }

        private readonly HashSet<IUART> uartsWithTesters;
        private readonly Dictionary<int, TerminalTester> testers;
    }
}
