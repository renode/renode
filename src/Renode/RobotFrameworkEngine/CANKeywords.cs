//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core.CAN;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Time;
using Antmicro.Renode.Tools.Network;

namespace Antmicro.Renode.RobotFramework
{
    internal class CANKeywords : TestersProvider<CANTester, CANHub>, IRobotFrameworkKeywordProvider
    {
        [RobotFrameworkKeyword]
        public string WaitForISOTPMessageHex(uint sendingId, uint receivingId, float? timeout = null, int? testerId = null, bool? pauseEmulation = null, bool keep = false)
        {
            var result = WaitForISOTPMessage(sendingId, receivingId, timeout, testerId, pauseEmulation, keep);
            return string.Concat(result.Select(b => b.ToString("X2")));
        }

        [RobotFrameworkKeyword]
        public byte[] WaitForFrameWithId(uint id, float? timeout = null, int? testerId = null, bool? pauseEmulation = null)
        {
            var matcher = new CANTester.CANMatcher(id);
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }
            var result = WaitForMatch(matcher, timeInterval, testerId, pauseEmulation);
            if(result is null)
            {
                throw new InvalidOperationException("CANTester failed, no matching frame found");
            }
            return result.Data;
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void SetDefaultCANTimeout(float timeout)
        {
            globalDefaultTimeout = timeout;
        }

        public void Dispose()
        {
            // Intentionally left blank
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public int CreateCANTester(string canHub, float? defaultTimeout = null, string machine = null)
        {
            return CreateNewTester(hub =>
            {
                var canTester = new CANTester(TimeInterval.FromSeconds(defaultTimeout ?? globalDefaultTimeout));
                hub.AttachTo(canTester);
                return canTester;
            }, canHub, machine);
        }

        [RobotFrameworkKeyword]
        public string SendUDSCommandAndWaitForPositiveResponse(uint senderId, uint receiverId, byte service, string data, float? timeout = null, int? testerId = null, bool? pauseEmulation = null, bool keep = false)
        {
            var bytes = Convert.FromHexString(data);
            var tester = GetTesterOrThrowException(testerId);
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }
            if(!tester.SendISOTPMessage(senderId, receiverId, bytes.Prepend(service).ToArray(), timeInterval))
            {
                // Failed to send message
                throw new InvalidOperationException("CANTester failed, failed to send UDS command");
            }
            var result = WaitForISOTPMessage(senderId, receiverId, timeout, testerId, pauseEmulation, keep);
            if(result is null)
            {
                // Timeout
                throw new InvalidOperationException("CANTester failed, timed out waiting for UDS response");
            }
            if(result[0] == service + 0x40)
            {
                return string.Concat(result.Select(b => b.ToString("X2")));
            }
            else if(result[0] == 0x7F)
            {
                // Negative reposnse
                throw new InvalidOperationException($"CANTester failed, got negative response with NRC 0x{result[2]:X}");
            }
            else
            {
                // Incorrect format
                throw new InvalidOperationException($"CANTester failed, invalid response SID 0x{result[0]}");
            }
        }

        [RobotFrameworkKeyword]
        public void SendISOTPMessage(uint sendingId, uint receivingId, string data, float? timeout = null, int? testerId = null)
        {
            var tester = GetTesterOrThrowException(testerId);
            var bytes = Convert.FromHexString(data);
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }
            tester.SendISOTPMessage(sendingId, receivingId, bytes, timeInterval);
        }

        private List<byte> WaitForISOTPMessage(uint sendingId, uint receivingId, float? timeout = null, int? testerId = null, bool? pauseEmulation = null, bool keep = false)
        {
            var tester = GetTesterOrThrowException(testerId);
            TimeInterval? timeInterval = null;
            if(timeout.HasValue)
            {
                timeInterval = TimeInterval.FromSeconds(timeout.Value);
            }
            var result = tester.WaitForISOTPMessage(sendingId, receivingId, pauseEmulation ?? true, keep, timeInterval);
            if(result is null)
            {
                throw new InvalidOperationException("CANTester failed, no matching ISOTP message");
            }
            return result;
        }

        private CANMessageFrame WaitForMatch(CANTester.CANMatcher matcher, TimeInterval? timeout = null, int? testerId = null, bool? pauseEmulation = null, bool keep = false)
        {
            var tester = GetTesterOrThrowException(testerId);
            return tester.WaitForMessageFrame(matcher, pauseEmulation ?? true, keep, timeout);
        }

        private float globalDefaultTimeout = 0;
    }
}