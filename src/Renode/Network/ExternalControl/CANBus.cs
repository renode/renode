//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.CAN;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CAN;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl;

public class CANBus(ExternalControlSocket parent) : BaseCommand(parent), IInstanceBasedCommand<CANExternalControlBus>, IEmulationElement
{
    public static int MaximumCanFrameSize = 64;

    public MessagePayload Invoke(CANExternalControlBus instance, ReadOnlySpan<byte> data)
    {
        if(data.Length < 1)
        {
            return MessagePayload.Error(Identifier, $"Expected at least {1 + InstanceBasedCommandHeaderSize} bytes of payload");
        }
        var command = (CANBusCommands)data[0];
        Logger.DebugLog(instance, "Received {0} command", command);

        switch(command)
        {
        case CANBusCommands.SendFrame:
            this.DebugLog("Received SendFrameCommand with data: {0}", data.ToArray().ToLazyHexString());

            var packet_length = BitConverter.ToUInt32(data[1..]);
            var id = BitConverter.ToUInt32(data[5..]);

            if(data.Length != packet_length + 9)
            {
                return MessagePayload.Error(Identifier, $"Incorrect number of bytes in payload. Expected {packet_length + 9}");
            }

            var packet = data[9..].ToArray();

            instance.SendFrame(packet, id);
            break;

        case CANBusCommands.RegisterCallbacks:
            var ed = BitConverter.ToInt32(data[1..]);
            Logger.DebugLog(this, "Attaching ReceivedMessage callback to instance '{0}'", instance.GetName());
            instance.ReceivedMessage += (frame) => ReceivedFrame(frame, ed);
            break;

        default:
            return MessagePayload.Error(Identifier, "Unexpected command format");
        }
        return MessagePayload.Success(Identifier);
    }

    public void ReceivedFrame(CANMessageFrame message, int callbackIndex)
    {
        var eventHeader = EventHeader.Create(EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime.TotalNanoseconds, message);

        var response = parent.SendRequest(MessagePayload.Event(Identifier, callbackIndex, eventHeader, message.Data));
        response.LogOnError(Identifier, parent);
    }

    public override MessagePayload Invoke(MessagePayload payload) => this.InvokeHandledWithInstance(payload);

    public override Command Identifier => Command.CANBus;

    public InstanceCollection<CANExternalControlBus> Instances { get; } = new InstanceCollection<CANExternalControlBus>();

    private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct EventHeader
    {
        public static EventHeader Create(ulong timestamp, CANMessageFrame message)
        {
            var len = message.Data.Length;
            if(len > MaximumCanFrameSize)
            {
                throw new ArgumentOutOfRangeException();
            }
            return new EventHeader() { TimestampNanoseconds = timestamp, Id = message.Id, PacketLength = len };
        }

        public ulong TimestampNanoseconds;

        public int PacketLength;

        public uint Id;
    }

    public enum CANBusCommands : byte
    {
        SendFrame = 0,
        RegisterCallbacks = 2,
    }
}
