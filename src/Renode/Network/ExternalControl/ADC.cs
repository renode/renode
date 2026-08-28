//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Sensor;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class ADC : BaseCommand, IInstanceBasedCommand<IADC>
    {
        public ADC(ExternalControlSocket parent)
            : base(parent)
        {
            Instances = new InstanceCollection<IADC>();
        }

        public override MessagePayload Invoke(MessagePayload payload) => this.InvokeHandledWithInstance(payload);

        public MessagePayload Invoke(IADC instance, ReadOnlySpan<byte> data)
        {
            if(data.Length < 1)
            {
                return MessagePayload.Error(Identifier, $"Expected at least {1 + InstanceBasedCommandHeaderSize} bytes of payload");
            }
            var command = (ADCCommand)data[0];

            var expectedCount = GetExpectedPayloadCount(command);
            if(expectedCount != data.Length)
            {
                return MessagePayload.Error(Identifier, $"Expected {expectedCount + InstanceBasedCommandHeaderSize} bytes of payload");
            }

            switch(command)
            {
            case ADCCommand.GetCount:
                var channelCount = instance.ADCChannelCount;
                parent.Log(LogLevel.Debug, "Executing ADC GetCount command, returned {0}", channelCount);
                return MessagePayload.Success(Identifier, channelCount.AsRawBytes());

            case ADCCommand.GetValue:
                DecodeChannelArgument(data, out var channel);
                var voltage = instance.GetVoltage(channel);
                parent.Log(LogLevel.Debug, "Executing ADC GetValue command, channel #{0} returned {1}", channel, voltage);
                return MessagePayload.Success(Identifier, voltage.AsRawBytes());

            case ADCCommand.SetValue:
                DecodeSetValueArguments(data, out channel, out voltage);
                parent.Log(LogLevel.Debug, "Executing ADC SetValue command, channel #{0} set to {1}", channel, voltage);
                instance.SetVoltage(voltage, channel);
                return MessagePayload.Success(Identifier);

            default:
                return MessagePayload.Error(Identifier, "Unexpected command format");
            }
        }

        public InstanceCollection<IADC> Instances { get; }

        public override Command Identifier => Command.ADC;

        private int GetExpectedPayloadCount(ADCCommand command)
        {
            switch(command)
            {
            case ADCCommand.GetValue:
                return sizeof(byte) + sizeof(uint);
            case ADCCommand.SetValue:
                return sizeof(byte) + sizeof(uint) * 2;
            default:
                return sizeof(byte);
            }
        }

        private void DecodeChannelArgument(ReadOnlySpan<byte> data, out int channel)
        {
            channel = BitConverter.ToInt32(data[1..]);
        }

        private void DecodeSetValueArguments(ReadOnlySpan<byte> data, out int channel, out uint value)
        {
            DecodeChannelArgument(data, out channel);
            value = BitConverter.ToUInt32(data[5..]);
        }

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        private enum ADCCommand : byte
        {
            GetCount = 0,
            GetValue,
            SetValue,
        }
    }
}
