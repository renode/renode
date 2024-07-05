//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class GPIOPort : BaseCommand, IInstanceBasedCommand<IPeripheral>
    {
        public GPIOPort(ExternalControlServer parent)
            : base(parent)
        {
            Instances = new InstanceCollection<IPeripheral>();
        }

        public override Response Invoke(List<byte> data) => this.InvokeHandledWithInstance(data, HasGPIO);

        public Response Invoke(IPeripheral instance, List<byte> data)
        {
            if(data.Count < 1)
            {
                return Response.CommandFailed(Identifier, $"Expected at least {1 + InstanceBasedCommandHeaderSize} bytes of payload");
            }
            var command = (GPIOPortCommand)data[0];

            var expectedCount = GetExpectedPayloadCount(command);
            if(expectedCount != data.Count)
            {
                return Response.CommandFailed(Identifier, $"Expected {expectedCount + InstanceBasedCommandHeaderSize} bytes of payload");
            }

            switch(command)
            {
                case GPIOPortCommand.GetState:
                    DecodeIdArgument(data, out var id);

                    if(instance is INumberedGPIOOutput sender)
                    {
                        if(sender.Connections.TryGetValue(id, out var gpio))
                        {
                            return Response.Success(Identifier, BitConverter.GetBytes(gpio.IsSet));
                        }
                        return Response.CommandFailed(Identifier, $"This instance does not provide GPIO output #{id}");
                    }
                    return Response.CommandFailed(Identifier, "This instance does not provide GPIO outputs");

                case GPIOPortCommand.SetState:
                    DecodeSetValueArguments(data, out id, out var value);

                    if(instance is IGPIOReceiver receiver)
                    {
                        receiver.OnGPIO(id, value);
                        return Response.Success(Identifier);
                    }
                    return Response.CommandFailed(Identifier, "This instance does not provide GPIO inputs");

                default:
                    return Response.CommandFailed(Identifier, "Unexpected command format");
            }
        }

        public InstanceCollection<IPeripheral> Instances { get; }

        public override Command Identifier => Command.GPIOPort;
        public override byte Version => 0x0;

        private static bool HasGPIO(IPeripheral instance)
        {
            return instance is INumberedGPIOOutput || instance is IGPIOReceiver;
        }

        private int GetExpectedPayloadCount(GPIOPortCommand command)
        {
            switch(command)
            {
                case GPIOPortCommand.GetState:
                    return sizeof(byte) + sizeof(uint);
                case GPIOPortCommand.SetState:
                    return sizeof(byte) * 2 + sizeof(uint);
                default:
                    return sizeof(byte);
            }
        }

        private void DecodeIdArgument(List<byte> data, out int id)
        {
            id = BitConverter.ToInt32(data.GetRange(1, sizeof(uint)).ToArray(), 0);
        }

        private void DecodeSetValueArguments(List<byte> data, out int id, out bool value)
        {
            DecodeIdArgument(data, out id);
            value = BitConverter.ToBoolean(data.GetRange(5, sizeof(byte)).ToArray(), 0);
        }

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        private enum GPIOPortCommand : byte
        {
            GetState = 0,
            SetState,
        }
    }
}
