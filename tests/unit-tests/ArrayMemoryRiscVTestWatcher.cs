//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Peripherals.Memory
{
    public class ArrayMemoryRiscVTestWatcher : ArrayMemory
    {
        public ArrayMemoryRiscVTestWatcher(ulong size) : base(size)
        {
        }

        public ArrayMemoryRiscVTestWatcher(byte[] source) : base(source)
        {
        }

        public override void WriteQuadWord(long offset, ulong value)
        {
            base.WriteQuadWord(offset, value);
            WatchTestResult(offset, value);
        }

        public override void WriteDoubleWord(long offset, uint value)
        {
            base.WriteDoubleWord(offset, value);
            WatchTestResult(offset, value);
        }

        public override void WriteWord(long offset, ushort value)
        {
            base.WriteWord(offset, value);
            WatchTestResult(offset, value);
        }

        public override void WriteByte(long offset, byte value)
        {
            base.WriteByte(offset, value);
            WatchTestResult(offset, value);
        }

        // If LSB(value) == 1 the test is finished.
        // The exit code is (value >> 1).
        // If exit code is zero - test passed
        // else test failed.
        // [1] https://github.com/riscv-software-src/riscv-isa-sim/blob/6dda4896cb06fb8c2981ae35856e101fa6e8ed13/fesvr/syscall.cc#L211-L224
        // [2] https://github.com/riscv-software-src/riscv-isa-sim/blob/6dda4896cb06fb8c2981ae35856e101fa6e8ed13/fesvr/htif.cc#L320-L323
        // [3] https://github.com/riscv-software-src/riscv-isa-sim/blob/6dda4896cb06fb8c2981ae35856e101fa6e8ed13/fesvr/syscall.cc#L228
        // [4] https://github.com/riscv/riscv-test-env/issues/13
        // [5] https://github.com/riscv-software-src/riscv-isa-sim/issues/364#issuecomment-607657754
        private void WatchTestResult(long offset, ulong value)
        {
            if(offset != 0x0)
            {
                return;
            }

            if(TestFinished)
            {
                // After test finished, it usually loops indefinitely on the test result procedure.
                // Spike simulator intercepts the result value and exits the process with the exit code
                // set to that value [1][2]][3]. In renode it's unpopular practice to quit renode as a result of program
                // behavior, so the value should be checked by the observer (Robot Framework test)
                // and decide what to do with pass/failure.
                return;
            }

            // See [4] above.
            if((value & TestFinishedMarker) != TestFinishedMarker)
            {
                // Some value was written, but it's not the end of the test yet.
                return;
            }

            TestFinished = true;
            this.InfoLog("TEST FINISHED");

            // See [5] above.
            var quadValue = this.ReadQuadWord(0);
            ExitCode = quadValue >> 1;
            if(ExitCode == 0)
            {
                this.InfoLog("TEST PASSED");
            }
            else
            {
                this.ErrorLog("TEST FAILED WITH EXIT CODE {0}", ExitCode);
            }
        }

        public bool TestFinished { get; private set; }
        public ulong ExitCode { get; private set; }
        private const ulong TestFinishedMarker = 1;
    }
}