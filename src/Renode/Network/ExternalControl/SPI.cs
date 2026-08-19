//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.SPI;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class SPI : BaseCommand, IInstanceBasedCommand<ExternalControlSPIPeripheral>
    {
        public SPI(ExternalControlSocket parent)
            : base(parent)
        {
            Instances = new InstanceCollection<ExternalControlSPIPeripheral>();
        }

        public override MessagePayload Invoke(List<byte> data) => this.InvokeHandledWithInstance(data);

        // The only SPI command is RegisterCallbacks
        public MessagePayload Invoke(ExternalControlSPIPeripheral instance, List<byte> data)
        {
            // [ed:4]
            if(data.Count != sizeof(uint))
            {
                return MessagePayload.Error(Identifier, $"Expected {sizeof(uint)} bytes of payload, received {data.Count}");
            }
            var ed = BitConverter.ToInt32(CollectionsMarshal.AsSpan(data));
            RegisterCallbacks(instance, ed);
            parent.Log(LogLevel.Debug, "Registered SPI callbacks (ed={0})", ed);
            return MessagePayload.Success(Identifier);
        }

        public override Command Identifier => Command.SPI;

        public InstanceCollection<ExternalControlSPIPeripheral> Instances { get; }

        private void RegisterCallbacks(ExternalControlSPIPeripheral instance, int ed)
        {
            instance.OnTransmit = (mosi) =>
            {
                var data = new TransmitEventData()
                {
                    Command = (byte)SpiEvent.Transmit,
                    Mosi = mosi,
                };

                var response = parent.SendRequest(MessagePayload.Event(Identifier, ed, data));
                response.LogOnError(Identifier, parent);

                return response.Data[0];
            };
            instance.OnFinishTransmission = () =>
            {
                var data = new FinishTransmissionEventData()
                {
                    Command = (byte)SpiEvent.FinishTransmission,
                };

                var response = parent.SendRequest(MessagePayload.Event(Identifier, ed, data));
                response.LogOnError(Identifier, parent);
            };
        }

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        private struct TransmitEventData
        {
            public byte Command;
            public byte Mosi;
        }

        private struct FinishTransmissionEventData
        {
            public byte Command;
        }

        private enum SpiEvent : byte
        {
            Transmit = 0,
            FinishTransmission = 1,
        }
    }
}

