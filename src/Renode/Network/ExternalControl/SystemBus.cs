//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class SystemBus : BaseCommand, IInstanceBasedCommand<IPeripheral>
    {
        public SystemBus(ExternalControlSocket parent) : base(parent)
        {
            Instances = new InstanceCollection<IPeripheral>();
        }

        public MessagePayload Invoke(IPeripheral instance, ReadOnlySpan<byte> data)
        {
            if(data.Length == 0)
            {
                return MessagePayload.Error(Identifier, $"Expected at least 1 byte of payload");
            }

            var operation = (Operation)data[0];

            switch(operation)
            {
            case Operation.GetName:
                return PerformGetName(instance);
            case Operation.RegisterCallbacks:
                return PerformRegisterCallbacks(instance, data);
            case Operation.Read:
            case Operation.Write:
                return PerformReadWrite(instance, data);
            default:
                throw new UnreachableException();
            }
        }

        public override MessagePayload Invoke(MessagePayload payload) => this.InvokeHandledWithInstance(payload);

        public override Command Identifier => Command.SystemBus;

        public InstanceCollection<IPeripheral> Instances { get; }

        private MessagePayload PerformRegisterCallbacks(IPeripheral instance, ReadOnlySpan<byte> data)
        {
            if(instance is ExternalControlBusPeripheral externalPeripheral)
            {
                var accessWidths = (AccessWidth)data[1];
                var accessTypes = (AccessType)data[2];
                var ed = BitConverter.ToInt32(data[3..]);
                if(!ValidateRegisterCallbackParameters(accessWidths, accessTypes, out var parameterError))
                {
                    return parameterError;
                }

                RegisterCallbacks(externalPeripheral, accessWidths, accessTypes, ed);
                parent.Log(LogLevel.Debug, "Registered sysbus callbacks (ed={0}, access_types=[{1}], access_widths=[{2}])", ed, accessTypes, accessWidths);
                return MessagePayload.Success(Identifier);
            }
            return MessagePayload.Error(Identifier,
                $"Invalid instance type: {instance.GetType().Name}, expected {nameof(ExternalControlBusPeripheral)}");
        }

        private void RegisterCallbacks(ExternalControlBusPeripheral instance, AccessWidth accessWidths, AccessType accessTypes, int ed)
        {
            if(accessWidths.HasFlag(AccessWidth.Byte))
            {
                if(accessTypes.HasFlag(AccessType.Read))
                {
                    instance.OnReadByte = (offset) => PerformCallbackRead(ed, offset, AccessWidth.Byte)[0];
                }
                if(accessTypes.HasFlag(AccessType.Write))
                {
                    instance.OnWriteByte = (offset, value) => PerformCallbackWrite(ed, offset, AccessWidth.Byte, new[] { value });
                }
            }

            if(accessWidths.HasFlag(AccessWidth.Word))
            {
                if(accessTypes.HasFlag(AccessType.Read))
                {
                    instance.OnReadWord = (offset) => BitConverter.ToUInt16(PerformCallbackRead(ed, offset, AccessWidth.Word), 0);
                }
                if(accessTypes.HasFlag(AccessType.Write))
                {
                    instance.OnWriteWord = (offset, value) => PerformCallbackWrite(ed, offset, AccessWidth.Word, BitConverter.GetBytes(value));
                }
            }

            if(accessWidths.HasFlag(AccessWidth.DoubleWord))
            {
                if(accessTypes.HasFlag(AccessType.Read))
                {
                    instance.OnReadDoubleWord = (offset) => BitConverter.ToUInt32(PerformCallbackRead(ed, offset, AccessWidth.DoubleWord), 0);
                }
                if(accessTypes.HasFlag(AccessType.Write))
                {
                    instance.OnWriteDoubleWord = (offset, value) => PerformCallbackWrite(ed, offset, AccessWidth.DoubleWord, BitConverter.GetBytes(value));
                }
            }

            if(accessWidths.HasFlag(AccessWidth.QuadWord))
            {
                if(accessTypes.HasFlag(AccessType.Read))
                {
                    instance.OnReadQuadWord = (offset) => BitConverter.ToUInt64(PerformCallbackRead(ed, offset, AccessWidth.QuadWord), 0);
                }
                if(accessTypes.HasFlag(AccessType.Write))
                {
                    instance.OnWriteQuadWord = (offset, value) => PerformCallbackWrite(ed, offset, AccessWidth.QuadWord, BitConverter.GetBytes(value));
                }
            }

            if(accessWidths.HasFlag(AccessWidth.MultiByte))
            {
                if(accessTypes.HasFlag(AccessType.Read))
                {
                    instance.OnReadBytes = (offset, count) => PerformCallbackRead(ed, offset, AccessWidth.MultiByte, count);
                }
                if(accessTypes.HasFlag(AccessType.Write))
                {
                    instance.OnWriteBytes = (offset, value, startingIndex, count) => PerformCallbackWrite(ed, offset, AccessWidth.MultiByte, value, startingIndex, count);
                }
            }
        }

        private byte[] PerformCallbackRead(int ed, ulong offset, AccessWidth width, int count = 1)
        {
            var header = new SystemBusEventHeader
            {
                Timestamp = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime.TotalNanoseconds,
                AccessType = AccessType.Read,
                AccessWidth = width,
                Address = offset,
                DataCount = (uint)count,
            };

            var expectedByteCount = (int)DataCountToByteCount(width, (ulong)count);
            var response = parent.SendRequest(MessagePayload.Event(Identifier, ed, header));
            response.LogOnError(Identifier, parent);
            if(response.Data.Length != expectedByteCount)
            {
                parent.ErrorLog("Unexpected read callback response legth: {0} expected {1} bytes", response.Data.Length, expectedByteCount);
                return new byte[expectedByteCount];
            }

            return response.Data;
        }

        private void PerformCallbackWrite(int ed, ulong offset, AccessWidth width, byte[] value, int startingIndex = 0, int count = 1)
        {
            var header = new SystemBusEventHeader
            {
                Timestamp = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime.TotalNanoseconds,
                AccessType = AccessType.Write,
                AccessWidth = width,
                Address = offset,
                DataCount = (uint)count,
            };

            var byteCount = DataCountToByteCount(width, (ulong)count);
            var payload = header.AsRawBytes().Concat(value.Skip(startingIndex).Take((int)byteCount));
            var response = parent.SendRequest(MessagePayload.Event(Identifier, ed, payload.ToArray()));
            response.LogOnError(Identifier, parent);
        }

        private bool ValidateParameters(Operation op, AccessWidth width, ulong dataSize, int commandDataCount, out MessagePayload error)
        {
            if(!Enum.IsDefined(typeof(Operation), op))
            {
                error = MessagePayload.Error(Identifier, $"Invalid system bus operation: {op}");
                return false;
            }

            if(!Enum.IsDefined(typeof(AccessWidth), width))
            {
                error = MessagePayload.Error(Identifier, $"Invalid access width: {width}");
                return false;
            }

            var expectedCommandSize = ReadWriteCommandHeaderSize;
            if(op == Operation.Write)
            {
                expectedCommandSize += (int)DataCountToByteCount(width, dataSize);
            }

            if(commandDataCount != (int)expectedCommandSize)
            {
                error = MessagePayload.Error(Identifier, $"Expected {expectedCommandSize + InstanceBasedCommandHeaderSize} bytes of payload");
                return false;
            }

            error = default;
            return true;
        }

        private bool ValidateRegisterCallbackParameters(AccessWidth accessWidths, AccessType accessTypes, out MessagePayload error)
        {
            if(accessWidths == default)
            {
                error = MessagePayload.Error(Identifier, "At least one access width must be specified.");
                return false;
            }

            if((accessWidths & ~ValidCallbackAccessWidths) != default)
            {
                error = MessagePayload.Error(Identifier, $"Invalid access width flags: {accessWidths}");
                return false;
            }

            if(accessTypes == default)
            {
                error = MessagePayload.Error(Identifier, "At least one access type must be specified.");
                return false;
            }

            if((accessTypes & ~ValidCallbackAccessTypes) != default)
            {
                error = MessagePayload.Error(Identifier, $"Invalid access type flags: {accessTypes}");
                return false;
            }

            error = default;
            return true;
        }

        private ulong DataCountToByteCount(AccessWidth width, ulong size)
        {
            return (width == AccessWidth.MultiByte ? 1 : (ulong)width) * size;
        }

        private MessagePayload PerformReadWrite(IPeripheral instance, ReadOnlySpan<byte> data)
        {
            var operation = (Operation)data[0];
            var accessWidth = (AccessWidth)data[1];
            var address = BitConverter.ToUInt64(data[2..]);
            var dataCount = BitConverter.ToUInt32(data[(2 + sizeof(ulong))..]);

            if(!ValidateParameters(operation, accessWidth, dataCount, data.Length, out var error))
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
                return MessagePayload.Error(Identifier,
                    $"Invalid instance type: {instance.GetType().Name}, expected {nameof(IPeripheral)} or {nameof(IBusController)}");
            }

            if(operation == Operation.Read)
            {
                return MessagePayload.Success(Identifier, PerformRead(sysbus, context, address, accessWidth, dataCount));
            }
            else
            {
                var writeData = data.Slice(ReadWriteCommandHeaderSize, (int)DataCountToByteCount(accessWidth, dataCount)).ToArray();
                PerformWrite(sysbus, context, address, accessWidth, writeData);
                return MessagePayload.Success(Identifier);
            }
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
                        throw new UnreachableException();
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
                        throw new UnreachableException();
                    }
                }
            }
        }

        private MessagePayload PerformGetName(IPeripheral instance)
        {
            try
            {
                return MessagePayload.Success(Identifier, instance.GetName());
            }
            catch(Exception e)
            {
                return MessagePayload.Error(Identifier, $"Failed to obtain the name of the peripheral: {e.Message}");
            }
        }

        private const AccessType ValidCallbackAccessTypes = AccessType.Read | AccessType.Write;

        private const AccessWidth ValidCallbackAccessWidths =
            AccessWidth.Byte |
            AccessWidth.Word |
            AccessWidth.DoubleWord |
            AccessWidth.QuadWord |
            AccessWidth.MultiByte;

        private const int InstanceBasedCommandHeaderSize = IInstanceBasedCommandExtensions.HeaderSize;

        private const int ReadWriteCommandHeaderSize =
            sizeof(Operation) +
            sizeof(AccessWidth) +
            sizeof(ulong) + // Address
            sizeof(uint); // Amount of units to write

        // Use Pack=1 to ensure there's no padding between fields
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct SystemBusEventHeader
        {
            public ulong Timestamp;
            public AccessType AccessType;
            public AccessWidth AccessWidth;
            public ulong Address;
            public uint DataCount;
        }

        private enum Operation : byte
        {
            Read = 0,
            Write = 1,
            GetName = 2,
            RegisterCallbacks = 3,
        }

        [Flags]
        private enum AccessType : byte
        {
            Read = 1,
            Write = 2,
        }

        [Flags]
        private enum AccessWidth : byte
        {
            Byte = 1,
            Word = 2,
            DoubleWord = 4,
            QuadWord = 8,
            MultiByte = 128,
        }
    }
}
