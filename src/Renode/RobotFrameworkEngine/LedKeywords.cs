//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.Testing;

namespace Antmicro.Renode.RobotFramework
{
    internal class LedKeywords : TestersProvider<LEDTester, ILed>, IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void SetDefaultLedTimeout(float timeout)
        {
            globalDefaultTimeout = timeout;
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public int CreateLedTester(string led, float? defaultTimeout = null, string machine = null)
        {
            return CreateNewTester(ledObject => new LEDTester(ledObject, defaultTimeout ?? globalDefaultTimeout), led, machine);
        }

        [RobotFrameworkKeyword]
        public void AssertLedState(bool state, float? timeout = null, int? testerId = null, bool pauseEmulation = false)
        {
            GetTesterOrThrowException(testerId).AssertState(state, timeout, pauseEmulation);
        }

        [RobotFrameworkKeyword]
        public void AssertAndHoldLedState(bool initialState, float timeoutAssert, float timeoutHold, int? testerId = null,
            bool pauseEmulation = false)
        {
            GetTesterOrThrowException(testerId).AssertAndHoldState(initialState, timeoutAssert, timeoutHold, pauseEmulation);
        }

        [RobotFrameworkKeyword]
        public void AssertLedDutyCycle(float testDuration, double expectedDutyCycle, double tolerance = 0.05, int? testerId = null,
            bool pauseEmulation = false)
        {
            GetTesterOrThrowException(testerId).AssertDutyCycle(testDuration, expectedDutyCycle, tolerance, pauseEmulation);
        }

        [RobotFrameworkKeyword]
        public void AssertLedIsBlinking(float testDuration, double onDuration, double offDuration, double tolerance = 0.05,
            int? testerId = null, bool pauseEmulation = false)
        {
            GetTesterOrThrowException(testerId).AssertIsBlinking(testDuration, onDuration, offDuration, tolerance, pauseEmulation);
        }

        private float globalDefaultTimeout = 0;
    }
}