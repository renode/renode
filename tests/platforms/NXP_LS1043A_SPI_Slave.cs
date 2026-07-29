using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.SPI;

namespace Antmicro.Renode.Peripherals.SPI
{
    public class NXP_LS1043A_SPI_Slave : ISPIPeripheral
    {
        public byte Transmit(byte data)
        {
            return (byte)(data + 1);
        }

        public void FinishTransmission()
        {
        }

        public void Reset()
        {
        }
    }
}