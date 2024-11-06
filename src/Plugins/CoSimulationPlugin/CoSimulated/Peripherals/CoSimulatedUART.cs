//
// Copyright (c) 2010-2024 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    [AllowedTranslations(AllowedTranslation.ByteToDoubleWord)]
    public class CoSimulatedUART : BaseDoubleWordCoSimulatedPeripheral, IUART
    {
        public CoSimulatedUART(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null)
            : base(machine, frequency, simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS, simulationContextLinux, simulationContextWindows, simulationContextMacOS, limitBuffer, timeout, address)
        {
            IRQ = new GPIO();
        }

        public void WriteChar(byte value)
        {
            Send((ActionType)UARTActionNumber.UARTRxd, 0, value);
        }

        public override void HandleReceivedMessage(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case (ActionType)UARTActionNumber.UARTTxd:
                    CharReceived?.Invoke((byte)message.Data);
                    break;
                default:
                    base.HandleReceivedMessage(message);
                    break;
            }
        }

        // StopBits, ParityBit and BaudRate are not in sync with the cosimulated model
        public Bits StopBits { get { return Bits.One; } }
        public Parity ParityBit { get { return Parity.None; } }
        public uint BaudRate { get { return 115200; } }

        public event Action<byte> CharReceived;

        public GPIO IRQ { get; private set; }

        protected override void HandleInterrupt(ProtocolMessage interrupt)
        {
            switch(interrupt.Address)
            {
                case RxdInterrupt:
                    IRQ.Set(interrupt.Data != 0);
                    break;
                default:
                    base.HandleInterrupt(interrupt);
                    break;
            }
        }

        private const ulong RxdInterrupt = 1;
    }

    // UARTActionNumber must be in sync with integration library
    public enum UARTActionNumber
    {
        UARTTxd = 13,
        UARTRxd = 14
    }
}
