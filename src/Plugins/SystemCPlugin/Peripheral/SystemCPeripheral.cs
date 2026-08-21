//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public unsafe partial class SystemCPeripheral : IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, IMultibyteWritePeripheral, INumberedGPIOOutput, IGPIOReceiver, IDirectAccessPeripheral, IHasBusRegistrationConstraints
    {
        public SystemCPeripheral(
                IMachine machine,
                string address = "127.0.0.1",
                int port = 0,
                int timeSyncPeriodUS = 1000,
                bool disableTimeoutCheck = false
        )
        {
            this.address = address;
            this.requestedPort = port;
            this.machine = machine;
            this.timeSyncPeriodUS = timeSyncPeriodUS;
            this.disableTimeoutCheck = disableTimeoutCheck;
            sysbus = machine.GetSystemBus(this);

            directAccessPeripherals = new Dictionary<int, IDirectAccessPeripheral>();

            messageLock = new object();

            backwardThread = new Thread(BackwardConnectionLoop)
            {
                IsBackground = true,
                Name = "SystemC.BackwardThread"
            };

            var innerConnections = new Dictionary<int, IGPIO>();
            for(int i = 0; i < NumberOfGPIOPins; i++)
            {
                innerConnections[i] = new GPIO();
            }
            Connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);

            // Timer unit is microseconds
            var timerName = "RenodeSystemCTimesyncTimer";
            var timesyncFrequency = 1000000UL;
            var timesyncLimit = (ulong)timeSyncPeriodUS;

            timesyncTimer = new LimitTimer(machine.ClockSource, timesyncFrequency, this, timerName, limit: timesyncLimit, enabled: false, eventEnabled: true, autoUpdate: true);
        }

        public byte[] ReadBytes(long offset, int count, IPeripheral context = null)
        {
            var result = new byte[count];
            for(var i = 0; i < count; i++)
            {
                result[i] = ReadByte(offset + i);
            }
            return result;
        }

        public void WriteBytes(long offset, byte[] bytes, int startingIndex, int count, IPeripheral context = null)
        {
            if(bytes.Length < startingIndex + count)
            {
                throw new RecoverableException($"Bytes array needs to have at least {startingIndex + count} elements");
            }

            for(var i = 0; i < count; i++)
            {
                WriteByte(offset + i, bytes[startingIndex + i]);
            }
        }

        public ulong ReadQuadWord(long offset)
        {
            return Read(8, offset);
        }

        public void WriteRegister(byte dataLength, long offset, ulong value, byte connectionIndex = 0)
        {
            WriteInternal(RenodeAction.WriteRegister, dataLength, offset, value, connectionIndex, out _);
        }

        public void Reset()
        {
            var request = new RenodeMessage(RenodeAction.Reset, 0, 0, 0, 0, 0);
            SendRequest(request, out var response);
        }

        public void OnGPIO(int number, bool value)
        {
            SendGpioUpdate(number, value, 0);
        }

        public void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            Write(dataLength, offset, value, connectionIndex, skipDmi: true);
        }

        public ulong ReadDirect(byte dataLength, long offset, byte connectionIndex)
        {
            return Read(dataLength, offset, connectionIndex, skipDmi: true);
        }

        public ulong ReadRegister(byte dataLength, long offset, byte connectionIndex = 0)
        {
            return ReadInternal(RenodeAction.ReadRegister, dataLength, offset, connectionIndex, out _);
        }

        public byte ReadByte(long offset)
        {
            return (byte)Read(1, offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            Write(2, offset, value);
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)Read(2, offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            Write(4, offset, value);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)Read(4, offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            Write(8, offset, value);
        }

        public void WriteByte(long offset, byte value)
        {
            Write(1, offset, value);
        }

        public void ValidateRegistrationPoint(BusRangeRegistration registrationPoint, IPeripheral context)
        {
            if(context is not ICPUWithMMU cpuWithMmu)
            {
                return;
            }

            var pageSize = cpuWithMmu.PageSize;
            if(registrationPoint.Range.StartAddress % pageSize == registrationPoint.Offset % pageSize)
            {
                return;
            }

            throw new RegistrationException(
                $"SystemC peripheral registration at 0x{registrationPoint.Range.StartAddress:X} with offset 0x{registrationPoint.Offset:X} " +
                $"is not aligned to the guest page size 0x{pageSize:X}."
            );
        }

        public void AddDirectConnection(byte connectionIndex, IDirectAccessPeripheral target)
        {
            if(directAccessPeripherals.ContainsKey(connectionIndex))
            {
                this.Log(LogLevel.Error, "Failed to add Direct Connection #{0} - connection with this index is already present", connectionIndex);
                return;
            }

            directAccessPeripherals.Add(connectionIndex, target);
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        public bool DisableNativeDmi
        {
            get => disableNativeDmi;
            set
            {
                if(disableNativeDmi == value)
                {
                    return;
                }
                disableNativeDmi = value;
                if(!value)
                {
                    // Nothing to do on DMI disabled -> enabled transition.
                    return;
                }
                InvalidateAllDmiRegions();
            }
        }

        public bool DisableDebugAccess { get; set; }

        public bool MapMemoryOnReadOrWriteOnlyDmiGrant { get; set; }

        // NumberOfGPIOPins must be equal to renode_bridge.h:NUM_GPIO
        public const int NumberOfGPIOPins = 1024;

        protected void SendGpioUpdate(int number, bool value, uint initiatorId)
        {
            // When GPIO connections are initialized, OnGPIO is called with
            // false value. The transport is not yet initialized in that case. We
            // can safely return, no special initialization is required.
            if(!connectionActive)
            {
                return;
            }
            this.NoisyLog("Renode-triggered GPIO {0}, value {1}", number, value);

            var payload = value ? 1UL : 0UL;
            var request = new RenodeMessage(RenodeAction.GPIOWrite, 0, 0, initiatorId, (ulong)number, payload);
            SendRequest(request, out var _);
        }

        protected virtual void HandleGpioWrite(int number, bool value, uint initiatorId)
        {
            Connections[number].Set(value);
        }

        protected readonly IMachine machine;

        private static BusAccessError TlmStatusErrorToBusAccessError(TlmStatus tlmStatus)
        {
            switch(tlmStatus)
            {
            case TlmStatus.Ok:
                throw new ArgumentException("TLM ok is not an error");
            case TlmStatus.Incomplete:
                throw new ArgumentException("Incomplete TLM transaction");
            case TlmStatus.GenericError:
                return BusAccessError.GenericError;
            case TlmStatus.AddressError:
                return BusAccessError.AddressError;
            case TlmStatus.CommandError:
                return BusAccessError.CommandError;
            case TlmStatus.BurstError:
                return BusAccessError.BurstError;
            case TlmStatus.ByteEnableError:
                return BusAccessError.ByteEnableError;
            default:
                throw new ArgumentException("Unexpected TLM status");
            }
        }

        private ulong Read(byte dataLength, long offset, byte connectionIndex = 0, bool skipDmi = false)
        {
            var value = ReadInternal(RenodeAction.Read, dataLength, offset, connectionIndex, out var dmiAllowed);
            if(!skipDmi && dmiAllowed)
            {
                TryMapDmiRegion((ulong)offset, true);
            }
            return value;
        }

        private ulong ReadInternal(RenodeAction action, byte dataLength, long offset, byte connectionIndex, out bool dmiAllowed)
        {
            dmiAllowed = false;
            DebugHelper.Assert(dataLength <= 8);
            var extensionFields = GetExtensionFields(out _, out _, out var semihosting, out var initiatorId);
            var dataLengthWithExtensionFields = (byte)(extensionFields | dataLength);
            var onCpuThread = sysbus.TryGetCurrentCPU(out var cpu) && cpu.OnPossessedThread;
            if(!DisableDebugAccess && (!onCpuThread || semihosting))
            {
                action = RenodeAction.ReadDebug;
            }
            var request = new RenodeMessage(action, dataLengthWithExtensionFields, connectionIndex, initiatorId, (ulong)offset, 0);

            if(!SendRequest(request, out var response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Read will return 0.");
                return 0;
            }

            // Debug transaction doesn't return status in response, so assume ok.
            var status = TlmStatus.Ok;
            if(action != RenodeAction.ReadDebug)
            {
                status = (TlmStatus)response.DataLength;
                if(status != TlmStatus.Ok)
                {
                    this.WarningLog("Read transaction of width {0} to offset 0x{1:X} failed with status: {2}", dataLength, offset, status);
                }
            }

            if(onCpuThread && !semihosting)
            {
                if(status != TlmStatus.Ok)
                {
                    throw new BusAccessException(TlmStatusErrorToBusAccessError(status));
                }

                TryToSkipTransactionTime(response.Address);
                dmiAllowed = response.ConnectionIndex == DmiSupported;
            }
            return response.Payload;
        }

        private void Write(byte dataLength, long offset, ulong value, byte connectionIndex = 0, bool skipDmi = false)
        {
            WriteInternal(RenodeAction.Write, dataLength, offset, value, connectionIndex, out var dmiAllowed);
            if(!skipDmi && dmiAllowed)
            {
                TryMapDmiRegion((ulong)offset, false);
            }
        }

        private void WriteInternal(RenodeAction action, byte dataLength, long offset, ulong value, byte connectionIndex, out bool dmiAllowed)
        {
            dmiAllowed = false;
            DebugHelper.Assert(dataLength <= 8);
            var extensionFields = GetExtensionFields(out _, out _, out var semihosting, out var initiatorId);
            var dataLengthWithExtensionFields = (byte)(extensionFields | dataLength);
            var onCpuThread = sysbus.TryGetCurrentCPU(out var cpu) && cpu.OnPossessedThread;
            if(!DisableDebugAccess && (!onCpuThread || semihosting))
            {
                action = RenodeAction.WriteDebug;
            }
            var request = new RenodeMessage(action, dataLengthWithExtensionFields, connectionIndex, initiatorId, (ulong)offset, value);

            if(!SendRequest(request, out var response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Write will have no effect.");
                return;
            }

            // Debug transaction doesn't return status in response, so assume ok.
            var status = TlmStatus.Ok;
            if(action != RenodeAction.WriteDebug)
            {
                status = (TlmStatus)response.DataLength;
                if(status != TlmStatus.Ok)
                {
                    this.WarningLog("Write transaction of width {0} to offset 0x{1:X} failed with status: {2}", dataLength, offset, status);
                }
            }

            if(onCpuThread && !semihosting)
            {
                if(status != TlmStatus.Ok)
                {
                    throw new BusAccessException(TlmStatusErrorToBusAccessError(status));
                }

                TryToSkipTransactionTime(response.Address);
                dmiAllowed = response.ConnectionIndex == DmiSupported;
            }
        }

        private ulong GetCurrentVirtualTimeUS()
        {
            // Truncate, as the SystemC integration uses microsecond resolution
            return (ulong)machine.LocalTimeSource.ElapsedVirtualTime.TotalMicroseconds;
        }

        private void SetupTimesync()
        {
            timesyncTimer.Enabled = true;
            var currentQuantum = machine.LocalTimeSource.Quantum;
            AdjustTimesyncToQuantum(currentQuantum, currentQuantum);
            machine.LocalTimeSource.QuantumChanged += AdjustTimesyncToQuantum;
            timesyncTimer.LimitReached += OnTimesyncTimerLimitReached;
        }

        private void TeardownTimesync()
        {
            machine.LocalTimeSource.QuantumChanged -= AdjustTimesyncToQuantum;
            timesyncTimer.LimitReached -= OnTimesyncTimerLimitReached;
            timesyncTimer.Reset();
        }

        private void AdjustTimesyncToQuantum(TimeInterval oldQuantum, TimeInterval newQuantum)
        {
            if(TimeInterval.FromMicroseconds(timesyncTimer.Limit) < newQuantum)
            {
                var newLimit = (ulong)newQuantum.TotalMicroseconds;
                this.Log(LogLevel.Warning, $"Requested time synchronization period of {timesyncTimer.Limit}us is smaller than local time source quantum - synchronization time will be changed to {newLimit}us to match it.");
                timesyncTimer.Limit = newLimit;
            }
        }

        private void OnTimesyncTimerLimitReached()
        {
            machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
            {
                var request = new RenodeMessage(RenodeAction.Timesync, 0, 0, 0, 0, GetCurrentVirtualTimeUS());
                SendRequest(request, out var response);
            });
        }

        // NOTE: Don't send anything via the `forwardSocket` from the background connection thread.
        //       This may lead to deadlocks, as SystemC blocks waiting for a response from this thread.
        private void BackwardConnectionLoop()
        {
            while(true)
            {
                if(!ReceiveBackwardRequest(out var message))
                {
                    return;
                }

                switch(message.ActionId)
                {
                case RenodeAction.Init:
                    SetupTimesync();
                    var timesyncResponse = new RenodeMessage(RenodeAction.Init, 0, 0, 0, 0, (ulong)timeSyncPeriodUS);
                    SendBackwardResponse(timesyncResponse);
                    break;
                case RenodeAction.GPIOWrite:
                    var gpioNumber = (int)message.Address;
                    var isSet = message.Payload == 1;
                    var initiatorId = message.InitiatorId;
                    HandleGpioWrite(gpioNumber, isSet, initiatorId);
                    SendBackwardResponse(message);
                    this.NoisyLog("SystemC-triggered GPIO {0}, value {1}", gpioNumber, isSet);
                    break;
                case RenodeAction.Write:
                    bool writeToSharedMem = false;
                    if(message.IsSystemBusConnection())
                    {
                        var targetMem = sysbus.FindMemory(message.Address);
                        if(targetMem != null)
                        {
                            writeToSharedMem = targetMem.Peripheral.UsingSharedMemory;
                        }
                        sysbus.TryGetCurrentCPU(out var icpu);
                        switch(message.DataLength)
                        {
                        case 1:
                            sysbus.WriteByte(message.Address, (byte)message.Payload, context: icpu);
                            break;
                        case 2:
                            sysbus.WriteWord(message.Address, (ushort)message.Payload, context: icpu);
                            break;
                        case 4:
                            sysbus.WriteDoubleWord(message.Address, (uint)message.Payload, context: icpu);
                            break;
                        case 8:
                            sysbus.WriteQuadWord(message.Address, message.Payload, context: icpu);
                            break;
                        default:
                            this.Log(LogLevel.Error, "SystemC integration error - invalid data length {0} sent through backward connection from the SystemC process.", message.DataLength);
                            break;
                        }
                    }
                    else
                    {
                        directAccessPeripherals[message.GetDirectConnectionIndex()].WriteDirect(
                                message.DataLength, (long)message.Address, message.Payload, message.ConnectionIndex);
                    }
                    var writeResponseMessage = new RenodeMessage(message.ActionId, message.DataLength,
                            writeToSharedMem ? (byte)RenodeMessage.DMIAllowed : (byte)RenodeMessage.DMINotAllowed, message.InitiatorId, message.Address, message.Payload);
                    SendBackwardResponse(writeResponseMessage);
                    break;
                case RenodeAction.Read:
                    ulong payload = 0;
                    bool readFromSharedMem = false;
                    if(message.IsSystemBusConnection())
                    {
                        var targetMem = sysbus.FindMemory(message.Address);
                        if(targetMem != null)
                        {
                            readFromSharedMem = targetMem.Peripheral.UsingSharedMemory;
                        }
                        sysbus.TryGetCurrentCPU(out var icpu);
                        switch(message.DataLength)
                        {
                        case 1:
                            payload = (ulong)sysbus.ReadByte(message.Address, context: icpu);
                            break;
                        case 2:
                            payload = (ulong)sysbus.ReadWord(message.Address, context: icpu);
                            break;
                        case 4:
                            payload = (ulong)sysbus.ReadDoubleWord(message.Address, context: icpu);
                            break;
                        case 8:
                            payload = (ulong)sysbus.ReadQuadWord(message.Address, context: icpu);
                            break;
                        default:
                            this.Log(LogLevel.Error, "SystemC integration error - invalid data length {0} sent through backward connection from the SystemC process.", message.DataLength);
                            break;
                        }
                    }
                    else
                    {
                        payload = directAccessPeripherals[message.GetDirectConnectionIndex()].ReadDirect(message.DataLength, (long)message.Address, message.ConnectionIndex);
                    }
                    var readResponseMessage = new RenodeMessage(message.ActionId, message.DataLength,
                            readFromSharedMem ? (byte)RenodeMessage.DMIAllowed : (byte)RenodeMessage.DMINotAllowed, message.InitiatorId, message.Address, payload);

                    SendBackwardResponse(readResponseMessage);
                    break;
                case RenodeAction.DMIReq:
                    var targetMemory = sysbus.FindMemory(message.Address);
                    var mapping = targetMemory?.GetFileMappingParameters(message.Address);
                    DMIMessage responseDMIMessage;
                    if(mapping == null)
                    {
                        responseDMIMessage = new DMIMessage(
                            message.ActionId,
                            RenodeMessage.DMINotAllowed,
                            new FileMappingParameters(0, 0, 0, "", IntPtr.Zero)
                        );
                    }
                    else
                    {
                        responseDMIMessage = new DMIMessage(
                            message.ActionId,
                            RenodeMessage.DMIAllowed,
                            mapping.Value
                        );
                    }
                    SendBackwardResponseDmi(responseDMIMessage);
                    break;
                case RenodeAction.InvalidateTBs:
                    TryToInvalidateTBs(message.Address, message.Payload);
                    SendBackwardResponse(message);
                    break;
                case RenodeAction.InvalidateDmiRange:
                    InvalidateDmiRegion(message.Address, message.Payload, message.InitiatorId);
                    SendBackwardResponse(message);
                    break;
                default:
                    OnUnhandledRenodeMessage(message);
                    break;
                }
            }
        }

        private void TryToInvalidateTBs(ulong startAddress, ulong endAddress)
        {
            foreach(var cpu in machine.SystemBus.GetCPUs().OfType<CPU.ICPU>())
            {
                var translationCPU = cpu as TranslationCPU;
                if(translationCPU != null)
                {
                    translationCPU.OrderTranslationBlocksInvalidation(checked((nint)startAddress), checked((nint)endAddress));
                }
            }
        }

        private void TryToSkipTransactionTime(ulong timeUS)
        {
            if(timeUS == 0)
            {
                return;
            }
            if(machine.SystemBus.TryGetCurrentCPU(out var icpu))
            {
                var baseCPU = icpu as BaseCPU;
                if(baseCPU != null)
                {
                    baseCPU.SkipTime(TimeInterval.FromMicroseconds(timeUS));
                }
                else
                {
                    this.Log(LogLevel.Error, "Failed to get CPU, all SystemC transactions processed as if they have no duration. This can desynchronize Renode and SystemC simulations.");
                }
            }
        }

        /// <summary>
        /// Corresponds to get_direct_mem_ptr on SystemC side.
        /// After receiving a native pointer, it attempts to register it for use by TranslationCPU.
        /// </summary>
        /// <param name="offset">address in target's address space</param>
        private void TryMapDmiRegion(ulong offset, bool isRead)
        {
            if(disableNativeDmi)
            {
                return;
            }

            if(!useNative || !NativeConfigured)
            {
                return;
            }

            if(!sysbus.TryGetCurrentCPU(out var cpu))
            {
                return;
            }

            // RenodeMessage.dataLength field for DMIReq indicates the kind of DMI access being requested.
            var dataLength = isRead ? (byte)TlmCommand.Read : (byte)TlmCommand.Write;
            DebugHelper.Assert(dataLength <= 8);
            var extensionFields = GetExtensionFields(out _, out _, out var semihosting, out var initiatorId);

            DebugHelper.Assert(!semihosting, "Mapping memory during semihosting call is forbidden");

            lock(initiators)
            {
                if(!initiators.TryGetValue(initiatorId, out var initiator))
                {
                    var registrationOffset = GetRegistrationOffsetForInitiator(cpu);
                    initiators[initiatorId] = new Initiator(cpu, registrationOffset);
                }
                else if(initiator.MappedRanges.ContainsPoint(offset))
                {
                    return;
                }
            }

            var dataLengthWithExtensionFields = (byte)(extensionFields | dataLength);
            var request = new RenodeMessage(RenodeAction.DMIReq, dataLengthWithExtensionFields, 0, initiatorId, offset, 0);
            if(!SendDmiRequest(request, out var dmiNativeMessage))
            {
                this.ErrorLog("Unable to receive response to DMI request");
                return;
            }

            var dmiAccess = dmiNativeMessage.DmiAccess;
            var startAddress = dmiNativeMessage.StartAddress;
            var endAddress = dmiNativeMessage.EndAddress;
            var mappedAddress = checked((nint)dmiNativeMessage.Pointer);

            var allowToMap = MapMemoryOnReadOrWriteOnlyDmiGrant ? dmiAccess != DmiAccess.None : dmiAccess == DmiAccess.ReadWrite;
            if(!allowToMap || mappedAddress == IntPtr.Zero || endAddress < startAddress)
            {
                return;
            }

            // Read+Write DMI access was confirmed, proceed to memory mapping.
            var range = startAddress.To(endAddress);
            if(cpu is ICPUWithMMU cpuWithMmu)
            {
                // The DMI region has to be aligned to the guest page size
                // to be registered in tlib. Shrink the range to the aligned
                // part of the region so that no memory outside of it is mapped.
                var pageSize = cpuWithMmu.PageSize;
                var alignedStartAddress = range.StartAddress.AlignUpToMultipleOf(pageSize);
                var alignedEndAddressExclusive = (range.EndAddress + 1).AlignDownToMultipleOf(pageSize);
                if(alignedEndAddressExclusive <= alignedStartAddress)
                {
                    this.WarningLog("SystemC returned a DMI region {0} that doesn't cover a full guest page, memory won't be mapped", range);
                    return;
                }
                range = new Range(alignedStartAddress, alignedEndAddressExclusive - alignedStartAddress);
            }

            if(!range.Contains(offset))
            {
                this.WarningLog("SystemC returned a DMI region {0} that does not contain requested offset 0x{1:X}.", range, offset);
                return;
            }

            lock(initiators)
            {
                if(!initiators.TryGetValue(initiatorId, out var initiator))
                {
                    return;
                }

                var mappedDmiRanges = initiator.MappedRanges;

                if(mappedDmiRanges.ContainsWholeRange(range))
                {
                    return;
                }

                var rangesToMap = new List<Range> { range };
                foreach(var existingRange in mappedDmiRanges)
                {
                    rangesToMap = rangesToMap.SelectMany(x => x.Subtract(existingRange)).ToList();
                    if(!rangesToMap.Any())
                    {
                        return;
                    }
                }

                mappedDmiRanges.Add(range);
                this.DebugLog("Requested mapped SystemC DMI region {0}", range);
                machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
                {
                    MapRanges(rangesToMap, startAddress, mappedAddress, cpu);
                    this.DebugLog("Mapped SystemC DMI region {0}", range);
                }, true);
            }
        }

        private void MapRanges(List<Range> rangesToMap, ulong startAddress, nint mappedAddress, ICPU cpu)
        {
            foreach(var rangeToMap in rangesToMap)
            {
                var pointerOffset = (long)(rangeToMap.StartAddress - startAddress);
                var rangeMappedAddress = new IntPtr(mappedAddress + pointerOffset);
                sysbus.MapMemory(new DmiMappedSegment(rangeToMap.StartAddress, rangeToMap.Size, rangeMappedAddress), this, context: cpu as ICPUWithMappedMemory);
            }
        }

        private void InvalidateDmiRegion(ulong startAddress, ulong endAddress, uint initiatorId)
        {
            if(startAddress == 0 && endAddress == ulong.MaxValue)
            {
                // <0, ulong.MaxValue> ranges aren't currently supported
                endAddress -= 1;
            }

            lock(initiators)
            {
                if(!initiators.TryGetValue(initiatorId, out var initiator))
                {
                    return;
                }

                if(initiator.Cpu is not TranslationCPU translationCpu)
                {
                    this.WarningLog("Ensure there is at least one uniquely identifiable CPU initiator registered for the peripheral");
                    return;
                }

                var mappedDmiRanges = initiator.MappedRanges;
                var range = (startAddress).To(endAddress);
                // The range has to be aligned to the guest page size
                // to be unregistered from tlib. Expand it to the
                // aligned boundaries to make sure the whole region
                // is invalidated.
                var pageSize = translationCpu.PageSize;
                var alignedStartAddress = range.StartAddress.AlignDownToMultipleOf(pageSize);
                var alignedEndAddressExclusive = (range.EndAddress + 1).AlignUpToMultipleOf(pageSize);
                range = new Range(alignedStartAddress, alignedEndAddressExclusive - alignedStartAddress);
                var intersectingRanges = mappedDmiRanges.Select(collectionRange => collectionRange.Intersect(range)).Where(r => r.HasValue);
                mappedDmiRanges.Remove(range);
                this.DebugLog("Requested invalidation of SystemC DMI region <0x{0:X}, 0x{1:X}>", startAddress, endAddress);
                machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
                {
                    UnmapRanges(intersectingRanges, initiator);
                    this.DebugLog("Invalidated SystemC DMI region <0x{0:X}, 0x{1:X}>", startAddress, endAddress);
                }, true);
            }
        }

        private void UnmapRanges(IEnumerable<Range?> ranges, Initiator initiator)
        {
            var translationCpu = initiator.Cpu as TranslationCPU;
            var offset = initiator.Offset;
            foreach(var range in ranges)
            {
                // MapMemory supports mapping segments with addresses relative to owner peripheral.
                // UnmapMemory always assumes absolute address, so take a registration offset into account.
                var invalidatedRange = new Range(checked(offset + range.Value.StartAddress), range.Value.Size);
                try
                {
                    sysbus.UnmapMemory(invalidatedRange, context: translationCpu);
                }
                catch(RecoverableException)
                {
                    this.DebugLog("Invalidated memory region is already unmapped {0}", invalidatedRange);
                }
                translationCpu.OrderTranslationBlocksInvalidation(checked((nint)invalidatedRange.StartAddress), checked((nint)invalidatedRange.EndAddress));
                this.DebugLog("Unmapped SystemC DMI region {0}", invalidatedRange);
            }
        }

        private void InvalidateAllDmiRegions()
        {
            lock(initiators)
            {
                foreach(var initiatorId in initiators.Keys)
                {
                    InvalidateDmiRegion(0, ulong.MaxValue, initiatorId);
                }
            }
        }

        private ulong GetRegistrationOffsetForInitiator(ICPU cpu)
        {
            ulong offset = 0;
            var busRanges = new List<BusRangeRegistration>();
            foreach(var context in sysbus.GetAllContextKeys())
            {
                foreach(var registration in sysbus.GetRegisteredPeripherals(context))
                {
                    if(registration.Peripheral != this)
                    {
                        continue;
                    }
                    var initiator = registration.RegistrationPoint.Initiator;
                    if(initiator == null)
                    {
                        continue;
                    }
                    else if(initiator != cpu)
                    {
                        continue;
                    }
                    else
                    {
                        offset = registration.RegistrationPoint.StartingPoint;
                        break;
                    }
                }
            }
            return offset;
        }

        private byte GetExtensionFields(out bool secure, out bool privileged, out bool semihosting, out uint initiatorId)
        {
            initiatorId = 0;
            if(sysbus.TryGetTransactionInitiator(out var initiator))
            {
                if(initiator is CPUCore cpu)
                {
                    initiatorId = cpu.MultiprocessingId;
                }
            }
            if(sysbus.TryGetCurrentContextState<CortexM.ContextState>(out var _, out var cpuState))
            {
                secure = cpuState.CpuSecure;
                privileged = cpuState.Privileged;
                semihosting = cpuState.Semihosting;
            }
            else
            {
                // Default values when transaction state isn't available.
                secure = true;
                privileged = true;
                semihosting = false;
            }

            return GetExtensionFieldsMask(secure, privileged);
        }

        private byte GetExtensionFieldsMask(bool secure, bool privileged)
        {
            byte mask = 0;
            if(secure)
            {
                mask |= 1 << 4;
            }
            if(privileged)
            {
                mask |= 1 << 5;
            }
            return mask;
        }

        private bool disableNativeDmi;
        private readonly LimitTimer timesyncTimer;
        private readonly Dictionary<int, IDirectAccessPeripheral> directAccessPeripherals;
        private readonly Dictionary<uint, Initiator> initiators = new Dictionary<uint, Initiator>();
        private readonly int timeSyncPeriodUS;
        private readonly IBusController sysbus;
        private const int DmiSupported = 1;

        private sealed class Initiator
        {
            public Initiator(ICPU cpu, ulong offset)
            {
                Cpu = cpu;
                Offset = offset;
                MappedRanges = new MinimalRangesCollection();
            }

            public ICPU Cpu { get; }

            public ulong Offset { get; }

            public MinimalRangesCollection MappedRanges { get; }
        }

        private sealed class DmiMappedSegment : IMappedSegment
        {
            public DmiMappedSegment(ulong startingOffset, ulong size, IntPtr pointer)
            {
                StartingOffset = startingOffset;
                Size = size;
                Pointer = pointer;
            }

            public void Touch()
            {
                // intentionally left blank
            }

            public IntPtr Pointer { get; }

            public ulong StartingOffset { get; }

            public ulong Size { get; }
        }
    }
}
