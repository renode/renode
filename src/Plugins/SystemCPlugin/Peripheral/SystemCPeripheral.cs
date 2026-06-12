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
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Time;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public unsafe partial class SystemCPeripheral : IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, INumberedGPIOOutput, IGPIOReceiver, IDirectAccessPeripheral
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
            var request = new RenodeMessage(RenodeAction.Reset, 0, 0, 0, 0);
            SendRequest(request, out var response);
        }

        public void OnGPIO(int number, bool value)
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
            var request = new RenodeMessage(RenodeAction.GPIOWrite, 0, 0, (ulong)number, payload);
            RenodeMessage response;

            if(!sysbus.TryGetCurrentCPU(out var cpu) || !cpu.OnPossessedThread)
            {
                if(SendSidebandRequest(request, out response))
                {
                    return;
                }
            }
            SendRequest(request, out response);
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
                InvalidateDmiRegion(0, ulong.MaxValue);
            }
        }

        protected readonly IMachine machine;

        private ulong Read(byte dataLength, long offset, byte connectionIndex = 0, bool skipDmi = false)
        {
            var value = ReadInternal(RenodeAction.Read, dataLength, offset, connectionIndex, out var dmiAllowed);
            if(!skipDmi && dmiAllowed)
            {
                TryMapDmiRegion((ulong)offset);
            }
            return value;
        }

        private ulong ReadInternal(RenodeAction action, byte dataLength, long offset, byte connectionIndex, out bool dmiAllowed)
        {
            dmiAllowed = false;
            var request = new RenodeMessage(action, dataLength, connectionIndex, (ulong)offset, 0);
            RenodeMessage response;

            if(!sysbus.TryGetCurrentCPU(out var cpu) || !cpu.OnPossessedThread)
            {
                if(SendSidebandRequest(request, out response))
                {
                    return response.Payload;
                }
            }

            if(!SendRequest(request, out response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Read will return 0.");
                return 0;
            }

            TryToSkipTransactionTime(response.Address);
            dmiAllowed = response.ConnectionIndex == DmiSupported;
            return response.Payload;
        }

        private void Write(byte dataLength, long offset, ulong value, byte connectionIndex = 0, bool skipDmi = false)
        {
            WriteInternal(RenodeAction.Write, dataLength, offset, value, connectionIndex, out var dmiAllowed);
            if(!skipDmi && dmiAllowed)
            {
                TryMapDmiRegion((ulong)offset);
            }
        }

        private void WriteInternal(RenodeAction action, byte dataLength, long offset, ulong value, byte connectionIndex, out bool dmiAllowed)
        {
            dmiAllowed = false;
            var request = new RenodeMessage(action, dataLength, connectionIndex, (ulong)offset, value);
            RenodeMessage response;

            if(!sysbus.TryGetCurrentCPU(out var cpu) || !cpu.OnPossessedThread)
            {
                if(SendSidebandRequest(request, out response))
                {
                    return;
                }
            }

            if(!SendRequest(request, out response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Write will have no effect.");
                return;
            }

            TryToSkipTransactionTime(response.Address);
            dmiAllowed = response.ConnectionIndex == DmiSupported;
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
                var request = new RenodeMessage(RenodeAction.Timesync, 0, 0, 0, GetCurrentVirtualTimeUS());
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
                case RenodeAction.GPIOWrite:
                    // We have to respond before GPIO state is changed, because SystemC is blocked until
                    // it receives the response. Setting the GPIO may require it to respond, e. g. when it
                    // is interracted with from an interrupt handler.
                    SendBackwardResponse(message);
                    var gpioNumber = (int)message.Address;
                    var isSet = message.Payload == 1;
                    Connections[gpioNumber].Set(isSet);
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
                            writeToSharedMem ? (byte)RenodeMessage.DMIAllowed : (byte)RenodeMessage.DMINotAllowed, message.Address, message.Payload);
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
                            readFromSharedMem ? (byte)RenodeMessage.DMIAllowed : (byte)RenodeMessage.DMINotAllowed, message.Address, payload);

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
                    InvalidateDmiRegion(message.Address, message.Payload);
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
        private void TryMapDmiRegion(ulong offset)
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

            foreach(var registrationPoint in sysbus.GetRegistrationPoints(this))
            {
                if(registrationPoint.Initiator != cpu)
                {
                    // Memory is mapped only when SystemC peripheral has a single initiator which is the current cpu.
                    // Otherwise unmapping memory in multicore machine would be ambigous and we could accidentaly unmap
                    // memory not owned by SystemC from the other core.
                    this.WarningLog("Peripheral must have unambiguous cpu initiator to support mapping of DMI region, try registering it for cpu context");
                    return;
                }
            }

            // RenodeMessage.dataLength field for DMIReq indicates the kind of DMI access being requested.
            var request = new RenodeMessage(RenodeAction.DMIReq, (byte)TlmCommand.Read, 0, offset, 0);
            if(!SendDmiRequest(request, out var dmiNativeMessage))
            {
                this.ErrorLog("Unable to receive response to DMI request");
                return;
            }

            var dmiAccess = dmiNativeMessage.DmiAccess;
            var startAddress = dmiNativeMessage.StartAddress;
            var endAddress = dmiNativeMessage.EndAddress;
            var mappedAddress = checked((nint)dmiNativeMessage.Pointer);

            if(dmiAccess == DmiAccess.None || mappedAddress == IntPtr.Zero || endAddress < startAddress)
            {
                return;
            }

            if(!dmiAccess.HasFlag(DmiAccess.Read))
            {
                // The requested access was not granted to the initiator.
                this.WarningLog("DMI read access wasn't granted to the initiator, memory won't be mapped");
                return;
            }

            if(dmiAccess != DmiAccess.ReadWrite)
            {
                // The target is allowed to promote Read/Write request to Read+Write.
                // If it hasn't done so, we can't tell whether it's on purpose
                // to ensure the other direction goes via blocking transport.
                // Currently we don't support memory mapping for read or write only,
                // so to ensure both access types are supported, we issue another DMI request
                // with the other access type.
                request = new RenodeMessage(RenodeAction.DMIReq, (byte)TlmCommand.Write, 0, offset, 0);
                if(!SendDmiRequest(request, out dmiNativeMessage))
                {
                    this.ErrorLog("Unable to receive response to DMI request");
                    return;
                }

                // At SystemC level, a target wishing to deny read and write access to the DMI region
                // should set the granted access type to DMI_ACCESS_READ_WRITE, not to DMI_ACCESS_NONE.
                // The rejection status is returned by get_direct_mem_ptr.
                // When access is denied, Renode SystemC bridge always sends back DMI_ACCESS_NONE.
                var dmiAccessWrite = dmiNativeMessage.DmiAccess;
                var startAddressWrite = dmiNativeMessage.StartAddress;
                var endAddressWrite = dmiNativeMessage.EndAddress;
                var mappedAddressWrite = checked((nint)dmiNativeMessage.Pointer);

                if(!dmiAccessWrite.HasFlag(DmiAccess.Write))
                {
                    this.WarningLog("DMI write access wasn't granted to the initiator, memory won't be mapped");
                    return;
                }

                if(startAddress != startAddressWrite || endAddress != endAddressWrite || mappedAddress != mappedAddressWrite)
                {
                    this.WarningLog("Inconsistency between DMI response for read and write access request to address 0x{0:X}, memory won't be mapped", offset);
                    return;
                }
            }

            // Read+Write DMI access was confirmed, proceed to memory mapping.
            var range = startAddress.To(endAddress);
            if(!range.Contains(offset))
            {
                this.WarningLog("SystemC returned a DMI region {0} that does not contain requested offset 0x{1:X}.", range, offset);
                return;
            }

            lock(mappedDmiRanges)
            {
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
                foreach(var rangeToMap in rangesToMap)
                {
                    var pointerOffset = (long)(rangeToMap.StartAddress - startAddress);
                    var rangeMappedAddress = new IntPtr(mappedAddress + pointerOffset);
                    sysbus.MapMemory(new DmiMappedSegment(rangeToMap.StartAddress, rangeToMap.Size, rangeMappedAddress), this, context: cpu as ICPUWithMappedMemory);
                }
            }

            this.DebugLog("Mapped SystemC DMI region {0}", range);
        }

        private void InvalidateDmiRegion(ulong startAddress, ulong endAddress)
        {
            this.DebugLog("Requested invalidation of SystemC DMI region <0x{0:X}, 0x{1:X}>", startAddress, endAddress);
            if(startAddress == 0 && endAddress == ulong.MaxValue)
            {
                // <0, ulong.MaxValue> ranges aren't currently supported
                endAddress -= 1;
            }

            ICPUWithMappedMemory cpu = null;
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
                        this.WarningLog("Peripheral must have unambiguous cpu initiator to support mapping of DMI region, try registering it for cpu context");
                        return;
                    }
                    else
                    {
                        if(cpu != null && initiator != cpu)
                        {
                            this.WarningLog("Peripheral must have unambiguous cpu initiator to support mapping of DMI region, try registering it for cpu context");
                            return;
                        }
                        if(initiator is ICPUWithMappedMemory cpuWithMappedMemory)
                        {
                            cpu = cpuWithMappedMemory;
                            busRanges.Add(registration.RegistrationPoint);
                        }
                    }
                }
            }

            if(!(cpu is TranslationCPU translationCpu))
            {
                return;
            }

            lock(mappedDmiRanges)
            {
                var range = startAddress.To(endAddress);
                var intersectingRanges = mappedDmiRanges.Select(collectionRange => collectionRange.Intersect(range)).Where(r => r.HasValue);
                foreach(var intersectingRange in intersectingRanges)
                {
                    foreach(var busRange in busRanges)
                    {
                        var invalidatedRange = new Range(checked(busRange.Range.StartAddress + intersectingRange.Value.StartAddress), intersectingRange.Value.Size);
                        sysbus.UnmapMemory(invalidatedRange, context: cpu);
                        translationCpu.OrderTranslationBlocksInvalidation(checked((nint)invalidatedRange.StartAddress), checked((nint)invalidatedRange.EndAddress));
                        this.DebugLog("Unmapped SystemC DMI region {0}", invalidatedRange);
                    }
                }
                mappedDmiRanges.Remove(range);
            }
        }

        private bool disableNativeDmi;
        private readonly LimitTimer timesyncTimer;
        private readonly Dictionary<int, IDirectAccessPeripheral> directAccessPeripherals;
        private readonly MinimalRangesCollection mappedDmiRanges = new MinimalRangesCollection();
        private readonly int timeSyncPeriodUS;
        private readonly IBusController sysbus;

        // NumberOfGPIOPins must be equal to renode_bridge.h:NUM_GPIO
        private const int NumberOfGPIOPins = 1024;
        private const int DmiSupported = 1;

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
