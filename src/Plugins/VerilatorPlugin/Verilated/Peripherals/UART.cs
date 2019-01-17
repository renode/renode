//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.Verilated
{
    [AllowedTranslations(AllowedTranslation.ByteToDoubleWord)]
    public class UART : BasePeripheral, IUART
    {
        public UART(Machine machine, string filePath, long frequency, ulong limit) : base (machine, filePath, frequency, limit)
        {
        }

        public void WriteChar(byte value)
        {
            mainSocket.Send(GetProtocol((ActionNumber)UARTActionNumber.UARTRxd, 0, value));
        }

        public Bits StopBits { get { return Bits.One; } }
        public Parity ParityBit { get { return Parity.None; } }
        public uint BaudRate { get { return 115200; } }
        public event Action<byte> CharReceived;

        protected override void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case (ActionNumber)UARTActionNumber.UARTTxd:
                    CharReceived?.Invoke((byte)message.Data);
                    break;
                default:
                    base.HandleReceived(message);
                    break;
            }
        }

        protected override void HandleInterrupt(ProtocolMessage interrupt)
        {
            switch(interrupt.Address)
            {
                case 1:
                    this.Log(LogLevel.Info, $"Rxd interrupt: {interrupt.Address}");
                    break;
                default:
                    base.HandleInterrupt(interrupt);
                    break;
            }
        }

        public enum UARTActionNumber
        {
            UARTTxd = 7,
            UARTRxd = 8
        }
    }
}
