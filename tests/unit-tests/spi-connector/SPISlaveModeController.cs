//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.SPI
{
    public class SPISlaveModeController : ISPIPeripheral, IDoubleWordPeripheral, IKnownSize
    {
        public uint ReadDoubleWord(long offset)
        {
            return 0x0;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
        }

        public byte Transmit(byte value)
        {
            this.Log(LogLevel.Info, "Slave received:{0} sent:{0}", value);
            return value;
        }

        public void FinishTransmission()
        {
            this.Log(LogLevel.Info, "Slave finished transmission");
        }

        public void Reset()
        {
        }

        public long Size => 0x100;
    }
}
