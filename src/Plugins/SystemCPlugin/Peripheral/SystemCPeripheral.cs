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
            WriteInternal(RenodeAction.WriteRegister, dataLength, offset, value, connectionIndex);
        }

        public void Reset()
        {
            var request = new RenodeMessage(RenodeAction.Reset, 0, 0, 0, 0);
            SendRequest(request, out var response);
        }

        public void OnGPIO(int number, bool value)
        {
            // When GPIO connections are initialized, OnGPIO is called with
            // false value. The socket is not yet initialized in that case. We
            // can safely return, no special initialization is required.
            if(forwardSocket == null)
            {
                return;
            }
            this.NoisyLog("Renode-triggered GPIO {0}, value {1}", number, value);

            var payload = value ? 1UL : 0UL;
            var request = new RenodeMessage(RenodeAction.GPIOWrite, 0, 0, (ulong)number, payload);
            SendRequest(request, out var response);
        }

        public void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            Write(dataLength, offset, value, connectionIndex);
        }

        public ulong ReadDirect(byte dataLength, long offset, byte connectionIndex)
        {
            return Read(dataLength, offset, connectionIndex);
        }

        public ulong ReadRegister(byte dataLength, long offset, byte connectionIndex = 0)
        {
            return ReadInternal(RenodeAction.ReadRegister, dataLength, offset, connectionIndex);
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

        protected readonly IMachine machine;

        private ulong Read(byte dataLength, long offset, byte connectionIndex = 0)
        {
            return ReadInternal(RenodeAction.Read, dataLength, offset, connectionIndex);
        }

        private ulong ReadInternal(RenodeAction action, byte dataLength, long offset, byte connectionIndex)
        {
            var request = new RenodeMessage(action, dataLength, connectionIndex, (ulong)offset, 0);
            if(!SendRequest(request, out var response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Read will return 0.");
                return 0;
            }

            TryToSkipTransactionTime(response.Address);

            return response.Payload;
        }

        private void Write(byte dataLength, long offset, ulong value, byte connectionIndex = 0)
        {
            WriteInternal(RenodeAction.Write, dataLength, offset, value, connectionIndex);
        }

        private void WriteInternal(RenodeAction action, byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            var request = new RenodeMessage(action, dataLength, connectionIndex, (ulong)offset, value);
            if(!SendRequest(request, out var response))
            {
                this.Log(LogLevel.Error, "Request to SystemCPeripheral failed, Write will have no effect.");
                return;
            }

            TryToSkipTransactionTime(response.Address);
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
                    translationCPU.OrderTranslationBlocksInvalidation(new IntPtr((int)startAddress), new IntPtr((int)endAddress));
                }
            }
        }

        private void TryToSkipTransactionTime(ulong timeUS)
        {
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

        private readonly LimitTimer timesyncTimer;
        private readonly Dictionary<int, IDirectAccessPeripheral> directAccessPeripherals;
        private readonly int timeSyncPeriodUS;
        private readonly IBusController sysbus;

        // NumberOfGPIOPins must be equal to renode_bridge.h:NUM_GPIO
        private const int NumberOfGPIOPins = 1024;
    }
}
