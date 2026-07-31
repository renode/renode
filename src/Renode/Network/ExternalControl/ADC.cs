//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Sensor;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class ADC : BaseCommand, IInstanceBasedCommand<IADC>
    {
        public ADC(ExternalControlServer parent)
            : base(parent)
        {
            Instances = new InstanceCollection<IADC>();
        }

        public override MessagePayload Invoke(List<byte> data) => this.InvokeHandledWithInstance(data);

        public MessagePayload Invoke(IADC instance, List<byte> data)
        {
            if(data.Count < 1)
            {
                return MessagePayload.Error(Identifier, $"Expected at least {1 + InstanceBasedCommandHeaderSize} bytes of payload");
            }
            var command = (ADCCommand)data[0];

            var expectedCount = GetExpectedPayloadCount(command);
            if(expectedCount != data.Count)
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
                var value = instance.GetADCValue(channel);
                parent.Log(LogLevel.Debug, "Executing ADC GetValue command, channel #{0} returned {1}", channel, value);
                return MessagePayload.Success(Identifier, value.AsRawBytes());

            case ADCCommand.SetValue:
                DecodeSetValueArguments(data, out channel, out value);
                parent.Log(LogLevel.Debug, "Executing ADC SetValue command, channel #{0} set to {1}", channel, value);
                instance.SetADCValue(channel, value);
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

        private void DecodeChannelArgument(List<byte> data, out int channel)
        {
            channel = BitConverter.ToInt32(data.GetRange(1, sizeof(uint)).ToArray(), 0);
        }

        private void DecodeSetValueArguments(List<byte> data, out int channel, out uint value)
        {
            DecodeChannelArgument(data, out channel);
            value = BitConverter.ToUInt32(data.GetRange(5, sizeof(uint)).ToArray(), 0);
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
