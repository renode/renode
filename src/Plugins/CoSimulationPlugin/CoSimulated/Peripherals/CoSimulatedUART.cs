//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    [AllowedTranslations(AllowedTranslation.ByteToDoubleWord)]
    public class CoSimulatedUART : CoSimulatedPeripheral, IUART
    {
        public CoSimulatedUART(Machine machine, int maxWidth = 64, bool useAbsoluteAddress = false, long frequency = VerilogTimeunitFrequency,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int mainListenPort = 0, int asyncListenPort = 0, bool createConnection = true,
            ulong renodeToCosimSignalsOffset = 0, Range? cosimToRenodeSignalRange = null)
            : base(machine, maxWidth, useAbsoluteAddress, frequency, limitBuffer, timeout, address, mainListenPort, asyncListenPort, createConnection, renodeToCosimSignalsOffset, cosimToRenodeSignalRange, 0, 0)
        {
            IRQ = new GPIO();
        }

        public void WriteChar(byte value)
        {
            connection.Send(this, (ActionType)UARTActionNumber.UARTRxd, 0, value);
        }

        public bool HandleReceivedMessage(ProtocolMessage message)
        {
            if(message.ActionId == (ActionType)UARTActionNumber.UARTTxd)
            {
                CharReceived?.Invoke((byte)message.Data);
                return true;
            }

            return false;
        }

        public override void ReceiveGPIOChange(int coSimNumber, bool value)
        {
            if(!cosimToRenodeSignalRange.HasValue)
            {
                this.Log(LogLevel.Warning, $"Received GPIO change from co-simulation, but no cosimToRenodeSignalRange is defined.");
                return;
            }

            var localNumber = coSimNumber - (int)cosimToRenodeSignalRange.Value.StartAddress;
            if(localNumber != RxdInterrupt)
            {
                this.Log(LogLevel.Warning, "Unhandled interrupt: '{0}'", localNumber);
                return;
            }

            IRQ.Set(value);
        }

        public override void OnConnectionAttached(CoSimulationConnection connection)
        {
            base.OnConnectionAttached(connection);
            connection.OnReceive += HandleReceivedMessage;
        }

        public override void OnConnectionDetached(CoSimulationConnection connection)
        {
            connection.OnReceive -= HandleReceivedMessage;
            base.OnConnectionDetached(connection);
        }

        public GPIO IRQ { get; private set; }

        // StopBits, ParityBit and BaudRate are not in sync with the cosimulated model
        public Bits StopBits { get { return Bits.One; } }

        public Parity ParityBit { get { return Parity.None; } }

        public uint BaudRate { get { return 115200; } }

        public event Action<byte> CharReceived;

        private const int RxdInterrupt = 1;
    }

    // UARTActionNumber must be in sync with integration library
    public enum UARTActionNumber
    {
        UARTTxd = 13,
        UARTRxd = 14
    }
}