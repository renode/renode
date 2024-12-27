using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.Test
{
    class ExecuteInLockPeripheral : IBytePeripheral, IKnownSize
    {
        public ExecuteInLockPeripheral(Machine machine)
        {
            this.machine = machine;
        }

        public void Reset()
        {
        }

        public byte ReadByte(long offset)
        {
            return 0;
        }

        public void WriteByte(long offset, byte value)
        {
            machine.ClockSource.ExecuteInLock(() =>
                {
                    this.Log(LogLevel.Info, $"Got write request with value 0x{value:X}");
                });
        }

        public long Size
        {
            get
            {
                return 1;
            }
        }

        private Machine machine;
    }
}
