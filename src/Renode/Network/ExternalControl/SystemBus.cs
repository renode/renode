//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class SystemBus : BaseCommand, IInstanceBasedCommand<IPeripheral>
    {
        public SystemBus(ExternalControlServer parent) : base(parent)
        {
            Instances = new InstanceCollection<IPeripheral>();
        }

        public Response Invoke(IPeripheral instance, List<byte> commandData)
        {
            if(commandData.Count < (int)MinimumPayloadSize)
            {
                return Response.CommandFailed(Identifier, $"Expected at least {MinimumPayloadSize + InstanceBasedCommandHeaderSize} bytes of payload");
            }

            var operation = (Operation)commandData[0];
            var accessWidth = (AccessWidth)commandData[1];
            var commandDataArray = commandData.ToArray();
            var address = BitConverter.ToUInt64(commandDataArray, 2);
            var dataCount = BitConverter.ToUInt32(commandDataArray, 2 + sizeof(ulong));

            if(!ValidateParameters(operation, accessWidth, dataCount, commandData, out var error))
            {
                return error;
            }

            IBusController sysbus;
            IPeripheral context;
            if(instance is IBusController bus)
            {
                sysbus = bus;
                context = null;
            }
            else if(instance is IBusPeripheral busPeripheral)
            {
                sysbus = busPeripheral.GetMachine().GetSystemBus(busPeripheral);
                context = busPeripheral;
            }
            else if(instance is IPeripheral peripheral)
            {
                sysbus = peripheral.GetMachine().SystemBus;
                context = peripheral;
            }
            else
            {
                return Response.CommandFailed(Identifier,
                    $"Invalid instance type: {instance.GetType().Name}, expected {nameof(IPeripheral)} or {nameof(IBusController)}");
            }

            switch(operation)
            {
            case Operation.Read:
                return Response.Success(Identifier, PerformRead(sysbus, context, address, accessWidth, dataCount));
            case Operation.Write:
                var writeData = commandData.GetRange(MinimumPayloadSize, (int)DataCountToByteCount(accessWidth, dataCount));
                PerformWrite(sysbus, context, address, accessWidth, writeData.ToArray());
                return Response.Success(Identifier);
            default:
                throw new Exception("Unreachable");
            }
        }

        public override Response Invoke(List<byte> data) => this.InvokeHandledWithInstance(data);

        public override Command Identifier => Command.SystemBus;

        public override byte Version => 0x0;

        public InstanceCollection<IPeripheral> Instances { get; }

        private bool ValidateParameters(Operation op, AccessWidth width, ulong dataSize, List<byte> commandData, out Response error)
        {
            if(!Enum.IsDefined(typeof(Operation), op))
            {
                error = Response.CommandFailed(Identifier, $"Invalid system bus operation: {op}");
                return false;
            }

            if(!Enum.IsDefined(typeof(AccessWidth), width))
            {
                error = Response.CommandFailed(Identifier, $"Invalid access width: {width}");
                return false;
            }

            var expectedCommandSize = MinimumPayloadSize;
            if(op == Operation.Write)
            {
                expectedCommandSize += (int)DataCountToByteCount(width, dataSize);
            }

            if(commandData.Count != (int)expectedCommandSize)
            {
                error = Response.CommandFailed(Identifier, $"Expected {expectedCommandSize + InstanceBasedCommandHeaderSize} bytes of payload");
                return false;
            }

            error = null;
            return true;
        }

        private ulong DataCountToByteCount(AccessWidth width, ulong size)
        {
            return (width == AccessWidth.MultiByte ? 1 : (ulong)width) * size;
        }

        private byte[] PerformRead(IBusController bus, IPeripheral context, ulong address, AccessWidth width, ulong size)
        {
            var data = new byte[DataCountToByteCount(width, size)];
            if(width == AccessWidth.MultiByte)
            {
                bus.ReadBytes(address, data.Length, data, 0, context: context);
            }
            else
            {
                for(var i = 0; i < data.Length; i += (int)width)
                {
                    switch(width)
                    {
                    case AccessWidth.Byte:
                        data[i] = bus.ReadByte(address + (ulong)i, context);
                        break;
                    case AccessWidth.Word:
                        data.SetBytesFromValue(bus.ReadWord(address + (ulong)i, context), i);
                        break;
                    case AccessWidth.DoubleWord:
                        data.SetBytesFromValue(bus.ReadDoubleWord(address + (ulong)i, context), i);
                        break;
                    case AccessWidth.QuadWord:
                        data.SetBytesFromValue(bus.ReadQuadWord(address + (ulong)i, context), i);
                        break;
                    default:
                        throw new Exception("Unreachable");
                    }
                }
            }
            return data;
        }

        private void PerformWrite(IBusController bus, IPeripheral context, ulong address, AccessWidth width, byte[] data)
        {
            if(width == AccessWidth.MultiByte)
            {
                bus.WriteBytes(data, address, context: context);
            }
            else
            {
                for(var i = 0; i < data.Length; i += (int)width)
                {
                    switch(width)
                    {
                    case AccessWidth.Byte:
                        bus.WriteByte(address + (ulong)i, data[i], context);
                        break;
                    case AccessWidth.Word:
                        bus.WriteWord(address + (ulong)i, BitConverter.ToUInt16(data, i), context);
                        break;
                    case AccessWidth.DoubleWord:
                        bus.WriteDoubleWord(address + (ulong)i, BitConverter.ToUInt32(data, i), context);
                        break;
                    case AccessWidth.QuadWord:
                        bus.WriteQuadWord(address + (ulong)i, BitConverter.ToUInt64(data, i), context);
                        break;
                    default:
                        throw new Exception("Unreachable");
                    }
                }
            }
        }

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        private const int MinimumPayloadSize =
            sizeof(Operation) +
            sizeof(AccessWidth) +
            sizeof(ulong) + // Address
            sizeof(uint); // Amount of units to write

        private enum Operation : byte
        {
            Read = 0,
            Write = 1,
        }

        private enum AccessWidth : byte
        {
            MultiByte = 0,
            Byte = 1,
            Word = 2,
            DoubleWord = 4,
            QuadWord = 8,
        }
    }
}