//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class GPIOPort : BaseCommand, IInstanceBasedCommand<IPeripheral>
    {
        public GPIOPort(ExternalControlSocket parent)
            : base(parent)
        {
            Instances = new InstanceCollection<IPeripheral>();
        }

        public MessagePayload Invoke(IPeripheral instance, ReadOnlySpan<byte> data)
        {
            if(data.Length < 1)
            {
                return MessagePayload.Error(Identifier, $"Expected at least {1 + InstanceBasedCommandHeaderSize} bytes of payload");
            }
            var command = (GPIOPortCommand)data[0];

            var expectedCount = GetExpectedPayloadCount(command);
            if(expectedCount != data.Length)
            {
                return MessagePayload.Error(Identifier, $"Expected {expectedCount + InstanceBasedCommandHeaderSize} bytes of payload");
            }

            switch(command)
            {
            case GPIOPortCommand.GetState:
                DecodeIdArgument(data, out var id);

                if(instance is INumberedGPIOOutput sender)
                {
                    if(sender.Connections.TryGetValue(id, out var gpio))
                    {
                        return MessagePayload.Success(Identifier, BitConverter.GetBytes(gpio.IsSet));
                    }
                    return MessagePayload.Error(Identifier, $"This instance does not provide GPIO output #{id}");
                }
                return MessagePayload.Error(Identifier, "This instance does not provide GPIO outputs");

            case GPIOPortCommand.SetState:
                DecodeSetValueArguments(data, out id, out var value);

                if(instance is IGPIOReceiver receiver)
                {
                    receiver.OnGPIO(id, value);
                    return MessagePayload.Success(Identifier);
                }
                return MessagePayload.Error(Identifier, "This instance does not provide GPIO inputs");

            case GPIOPortCommand.RegisterEvent:
                DecodeRegisterEventArguments(data, out id, out var ed);

                if(!(instance is INumberedGPIOOutput gpioDriver))
                {
                    return MessagePayload.Error(Identifier, "This instance does not provide GPIO outputs");
                }

                if(!gpioDriver.Connections.TryGetValue(id, out var pin) || !(pin is GPIO))
                {
                    return MessagePayload.Error(Identifier, $"This instance does not provide GPIO output #{id}");
                }

                (pin as GPIO).AddStateChangedHook((state) => SendEvent(state, ed));
                return MessagePayload.Success(Identifier);

            default:
                return MessagePayload.Error(Identifier, "Unexpected command format");
            }
        }

        public void RegisterExternalCallback(int machineId, string externalGPIO, int pinId, Action<TimeStamp, bool> callback)
        {
            var gpioId = ((IInstanceBasedCommand<IPeripheral>)this).GetExternalInstanceId(parent, machineId, externalGPIO);

            int callbackId;
            lock(externalCallbacks)
            {
                callbackId = externalCallbacks.Count;
                externalCallbacks.Add(callback);
            }
            var data = BitConverter.GetBytes(gpioId)
                .Append((byte)GPIOPortCommand.RegisterEvent)
                .Concat(BitConverter.GetBytes(pinId))
                .Concat(BitConverter.GetBytes(callbackId));
            var response = parent.SendRequest(new MessagePayload(Identifier, CommandType.Request, data.ToArray()));
            response.ThrowOnError(Identifier);
        }

        public override MessagePayload Invoke(MessagePayload payload)
        {
            return payload.Type switch
            {
                CommandType.Request => this.InvokeHandledWithInstance(payload, HasGPIO),
                CommandType.EventRequest => HandleEventRequest(payload.Data),
                _ => MessagePayload.Error($"Unexpected command type"),

            };
        }

        public override Command Identifier => Command.GPIOPort;

        public InstanceCollection<IPeripheral> Instances { get; }

        private static bool HasGPIO(IPeripheral instance)
        {
            return instance is INumberedGPIOOutput || instance is IGPIOReceiver;
        }

        private MessagePayload HandleEventRequest(byte[] data)
        {
            EventData eventData;

            try
            {
                eventData = data.ToStruct<EventData>();
            }
            catch
            {
                return MessagePayload.Error(Identifier, "Can't decode event request");
            }
            var timestamp = new TimeStamp(TimeInterval.FromNanoseconds(eventData.TimestampNanoseconds), EmulationManager.ExternalWorld);

            Action<TimeStamp, bool> callback;
            lock(externalCallbacks)
            {
                if(eventData.CallbackIdentifier >= externalCallbacks.Count)
                {
                    parent.Log(LogLevel.Warning, "Can't process event request, invalid callback ID");
                    return MessagePayload.Error("Invalid callback ID");
                }
                callback = externalCallbacks[eventData.CallbackIdentifier];
            }
            callback.Invoke(timestamp, eventData.GpioState);

            return MessagePayload.Success(Identifier);
        }

        private void SendEvent(bool gpioState, int eventDescriptor)
        {
            var data = new EventData()
            {
                CallbackIdentifier = eventDescriptor,
                TimestampNanoseconds = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime.TotalNanoseconds,
                GpioState = gpioState,
            };

            var response = parent.SendRequest(MessagePayload.FromStruct(Identifier, CommandType.EventRequest, data));
            response.LogOnError(Identifier, parent);
        }

        private int GetExpectedPayloadCount(GPIOPortCommand command)
        {
            switch(command)
            {
            case GPIOPortCommand.GetState:
                return sizeof(byte) + sizeof(uint);
            case GPIOPortCommand.SetState:
                return sizeof(byte) * 2 + sizeof(uint);
            case GPIOPortCommand.RegisterEvent:
                return sizeof(byte) + sizeof(uint) * 2;
            default:
                return sizeof(byte);
            }
        }

        private void DecodeIdArgument(ReadOnlySpan<byte> data, out int id)
        {
            id = BitConverter.ToInt32(data[1..]);
        }

        private void DecodeSetValueArguments(ReadOnlySpan<byte> data, out int id, out bool value)
        {
            DecodeIdArgument(data, out id);
            value = BitConverter.ToBoolean(data[5..]);
        }

        private void DecodeRegisterEventArguments(ReadOnlySpan<byte> data, out int id, out int ed)
        {
            DecodeIdArgument(data, out id);
            ed = BitConverter.ToInt32(data[5..]);
        }

        private readonly List<Action<TimeStamp, bool>> externalCallbacks = new();

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct EventData
        {
            public int CallbackIdentifier;
            public ulong TimestampNanoseconds;
            [MarshalAs(UnmanagedType.I1)] // Make the field a single byte
            public bool GpioState;
        }

        private enum GPIOPortCommand : byte
        {
            GetState = 0,
            SetState,
            RegisterEvent,
        }
    }
}
