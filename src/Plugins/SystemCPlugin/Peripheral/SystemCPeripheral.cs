//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public enum RenodeAction : byte
    {
        Init = 0,
        Read = 1,
        Write = 2,
        Timesync = 3,
        GPIOWrite = 4,
        Reset = 5,
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RenodeMessage
    {
        public RenodeMessage(RenodeAction actionId, byte dataLength, byte connectionIndex, ulong address, ulong payload)
        {
            ActionId = actionId;
            DataLength = dataLength;
            ConnectionIndex = connectionIndex;
            Address = address;
            Payload = payload;
        }

        public byte[] Serialize()
        {
            var size = Marshal.SizeOf(this);
            var result = new byte[size];
            var handler = default(GCHandle);

            try
            {
                handler = GCHandle.Alloc(result, GCHandleType.Pinned);
                Marshal.StructureToPtr(this, handler.AddrOfPinnedObject(), false);
            }
            finally
            {
                if(handler.IsAllocated)
                {
                    handler.Free();
                }
            }

            return result;
        }

        public void Deserialize(byte[] message)
        {
            var handler = default(GCHandle);
            try
            {
                handler = GCHandle.Alloc(message, GCHandleType.Pinned);
                this = (RenodeMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(RenodeMessage));
            }
            finally
            {
                if(handler.IsAllocated)
                {
                    handler.Free();
                }
            }
        }

        public override string ToString()
        {
            return $"RenodeMessage [{ActionId}@{ConnectionIndex}:{Address}] {Payload}";
        }

        public bool IsSystemBusConnection() => ConnectionIndex == MainSystemBusConnectionIndex;
        public bool IsDirectConnection() => !IsSystemBusConnection();

        public byte GetDirectConnectionIndex()
        {
            if(!IsDirectConnection())
            {
                Logger.Log(LogLevel.Error, "Message for main system bus connection does not have a direct connection index.");
                return 0xff;
            }
            return (byte)(ConnectionIndex - 1);
        }

        private const byte MainSystemBusConnectionIndex = 0;

        public readonly RenodeAction ActionId;
        public readonly byte DataLength;
        public readonly byte ConnectionIndex;
        public readonly ulong Address;
        public readonly ulong Payload;
    }

    public interface IDirectAccessPeripheral : IPeripheral
    {
        ulong ReadDirect(byte dataLength, long offset, byte connectionIndex);
        void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex);
    };

    public class SystemCPeripheral : IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, INumberedGPIOOutput, IGPIOReceiver, IDirectAccessPeripheral, IDisposable
    {
        public SystemCPeripheral(
                IMachine machine,
                string address,
                int port,
                int timeSyncPeriodUS = 1000,
                bool disableTimeoutCheck = false
        )
        {
            this.address = address;
            this.port = port;
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

        public string SystemCExecutablePath
        {
            get => systemcExecutablePath;
            set
            {
                try
                {
                    systemcExecutablePath = value;
                    var connectionParams = $"{address} {port}";
                    StartSystemCProcess(systemcExecutablePath, connectionParams);
                    SetupConnection();
                    SetupTimesync();
                }
                catch(Exception e)
                {
                    throw new RecoverableException($"Failed to start SystemC process: {e.Message}");
                }
            }
        }

        public ulong ReadQuadWord(long offset)
        {
            return Read(8, offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            Write(8, offset, value);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)Read(4, offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            Write(4, offset, value);
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)Read(2, offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            Write(2, offset, value);
        }

        public byte ReadByte(long offset)
        {
            return (byte)Read(1, offset);
        }

        public void WriteByte(long offset, byte value)
        {
            Write(1, offset, value);
        }

        public ulong ReadDirect(byte dataLength, long offset, byte connectionIndex)
        {
            return Read(dataLength, offset, connectionIndex);
        }

        public void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            Write(dataLength, offset, value, connectionIndex);
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

            BitHelper.SetBit(ref outGPIOState, (byte)number, value);
            var request = new RenodeMessage(RenodeAction.GPIOWrite, 0, 0, 0, outGPIOState);
            SendRequest(request);
        }

        public void Reset()
        {
            outGPIOState = 0;
            var request = new RenodeMessage(RenodeAction.Reset, 0, 0, 0, 0);
            SendRequest(request);
        }

        public void Dispose()
        {
            if(systemcProcess != null && !systemcProcess.HasExited)
            {
                // Init message sent after connection has been established signifies Renode terminated and SystemC process
                // should exit.
                var request = new RenodeMessage(RenodeAction.Init, 0, 0, 0, 0);
                SendRequest(request);

                if(!systemcProcess.WaitForExit(500)) {
                    this.Log(LogLevel.Info, "SystemC process failed to exit gracefully - killing it.");
                    systemcProcess.Kill();
                }
            }
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        private ulong Read(byte dataLength, long offset, byte connectionIndex = 0)
        {
            var request = new RenodeMessage(RenodeAction.Read, dataLength, connectionIndex, (ulong)offset, 0);
            var response = SendRequest(request);

            TryToSkipTransactionTime(response.Address);

            return response.Payload;
        }

        private void Write(byte dataLength, long offset, ulong value, byte connectionIndex = 0)
        {
            var request = new RenodeMessage(RenodeAction.Write, dataLength, connectionIndex, (ulong)offset, value);
            var response = SendRequest(request);

            TryToSkipTransactionTime(response.Address);
        }

        private ulong GetCurrentVirtualTimeUS()
        {
            // Truncate, as the SystemC integration uses microsecond resolution
            return (ulong)machine.LocalTimeSource.ElapsedVirtualTime.TotalMicroseconds;
        }

        private void StartSystemCProcess(string systemcExecutablePath, string connectionParams)
        {
            try
            {
                systemcProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(systemcExecutablePath)
                    {
                        UseShellExecute = false,
                        Arguments = connectionParams
                    }
                };

                systemcProcess.Start();
            }
            catch(Exception e)
            {
                throw new RecoverableException(e.Message);
            }
        }

        private void SetupConnection()
        {
            var listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listener.Bind(new IPEndPoint(IPAddress.Parse(address), port));
            listener.Listen(2);

            this.Log(LogLevel.Info, "SystemCPeripheral waiting for forward SystemC connection on {0}:{1}", address, port);
            forwardSocket = listener.Accept();
            forwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for forwardSocket if the disableTimeoutCheck constructor argument is set - so if a debugger halts the SystemC process, Renode will wait for the process to restart
            if(!disableTimeoutCheck)
            {
                forwardSocket.ReceiveTimeout = 1000;
            }

            backwardSocket = listener.Accept();
            backwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for backwardSocket - it runs on a dedicated thread and by design blocks on Receive until a message arrives from SystemC process.

            SendRequest(new RenodeMessage(RenodeAction.Init, 0, 0, 0, (ulong)timeSyncPeriodUS));

            backwardThread.Start();
        }

        private void SetupTimesync()
        {
            // Timer unit is microseconds
            var timerName = "RenodeSystemCTimesyncTimer";
            var timesyncFrequency = 1000000;
            var timesyncLimit = (ulong)timeSyncPeriodUS;

            var timesyncTimer = new LimitTimer(machine.ClockSource, timesyncFrequency, this, timerName, limit: timesyncLimit, enabled: true, eventEnabled: true, autoUpdate: true);

            Action<TimeInterval, TimeInterval> adjustTimesyncToQuantum = ((_, newQuantum) => {
                if(TimeInterval.FromMicroseconds(timesyncTimer.Limit) < newQuantum)
                {
                    var newLimit = (ulong)newQuantum.TotalMicroseconds;
                    this.Log(LogLevel.Warning, $"Requested time synchronization period of {timesyncTimer.Limit}us is smaller than local time source quantum - synchronization time will be changed to {newLimit}us to match it.");
                    timesyncTimer.Limit = newLimit;
                }
            });
            var currentQuantum = machine.LocalTimeSource.Quantum;
            adjustTimesyncToQuantum(currentQuantum, currentQuantum);
            machine.LocalTimeSource.QuantumChanged += adjustTimesyncToQuantum;

            timesyncTimer.LimitReached += () =>
            {
                machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
                {
                    var request = new RenodeMessage(RenodeAction.Timesync, 0, 0, 0, GetCurrentVirtualTimeUS());
                    SendRequest(request);
                });
            };
        }

        private RenodeMessage SendRequest(RenodeMessage request)
        {
            lock (messageLock)
            {
                var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
                var recvBytes = new byte[messageSize];

                forwardSocket.Send(request.Serialize(), SocketFlags.None);
                forwardSocket.Receive(recvBytes, 0, messageSize, SocketFlags.None);

                var responseMessage = new RenodeMessage();
                responseMessage.Deserialize(recvBytes);

                return responseMessage;
            }
        }

        private void BackwardConnectionLoop()
        {
            while(true)
            {
                var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
                var recvBytes = new byte[messageSize];

                var nbytes = backwardSocket.Receive(recvBytes, 0, messageSize, SocketFlags.None);
                if(nbytes == 0) {
                    this.Log(LogLevel.Info, "Backward connection to SystemC process closed.");
                    return;
                }

                var message = new RenodeMessage();
                message.Deserialize(recvBytes);

                ulong payload = 0;
                switch(message.ActionId)
                {
                    case RenodeAction.GPIOWrite:
                        // We have to respond before GPIO state is changed, because SystemC is blocked until
                        // it receives the response. Setting the GPIO may require it to respond, e. g. when it
                        // is interracted with from an interrupt handler.
                        backwardSocket.Send(message.Serialize(), SocketFlags.None);
                        for(int pin = 0; pin < NumberOfGPIOPins; pin++)
                        {
                            bool irqval = (message.Payload & (1UL << pin)) != 0;
                            Connections[pin].Set(irqval);
                        }
                        break;
                    case RenodeAction.Write:
                        if(message.IsSystemBusConnection())
                        {
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
                        backwardSocket.Send(message.Serialize(), SocketFlags.None);
                        break;
                    case RenodeAction.Read:
                        if(message.IsSystemBusConnection())
                        {
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
                        var responseMessage = new RenodeMessage(message.ActionId, message.DataLength,
                                message.ConnectionIndex, message.Address, payload);
                        backwardSocket.Send(responseMessage.Serialize(), SocketFlags.None);
                        break;
                    default:
                        this.Log(LogLevel.Error, "SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId); 
                        break;
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

        private readonly IBusController sysbus;
        private readonly IMachine machine;

        // NumberOfGPIOPins must be equal to renode_bridge.h:NUM_GPIO
        private const int NumberOfGPIOPins = 64;

        private readonly string address;
        private readonly int port;
        private readonly int timeSyncPeriodUS;
        private readonly bool disableTimeoutCheck;
        private readonly object messageLock;

        private readonly Thread backwardThread;

        private Dictionary<int, IDirectAccessPeripheral> directAccessPeripherals;
        private string systemcExecutablePath;
        private Process systemcProcess;

        private ulong outGPIOState;

        private Socket forwardSocket;
        private Socket backwardSocket;
    }
}
