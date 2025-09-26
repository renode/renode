//
// Copyright (c) 2010-2025 Antmicro
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
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

#if !PLATFORM_WINDOWS
using Mono.Unix.Native;
#endif

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
        DMIReq = 6,
        InvalidateTBs = 7,
        ReadRegister = 8,
        WriteRegister = 9,
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

        public const int DMIAllowed = 1;
        public const int DMINotAllowed = 0;

        private const byte MainSystemBusConnectionIndex = 0;

        public readonly RenodeAction ActionId;
        public readonly byte DataLength;
        public readonly byte ConnectionIndex;
        public readonly ulong Address;
        public readonly ulong Payload;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DMIMessage
    {
        public DMIMessage(RenodeAction actionId, byte allowed, ulong startAddress, ulong endAddress, ulong mmfOffset, string mmfPath)
        {
            ActionId = actionId;
            Allowed = allowed;
            StartAddress = startAddress;
            EndAddress = endAddress;
            MMFOffset = mmfOffset;
            MMFPath = new byte[256];
            byte[] mmfPathBytes = Encoding.ASCII.GetBytes(mmfPath);
            if(mmfPathBytes.Length > 256)
            {
                Logger.Log(LogLevel.Error, "MMF path name is too long");
            }
            else
            {
                Array.Copy(mmfPathBytes, MMFPath, Math.Min(mmfPathBytes.Length, MMFPath.Length));
            }
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
                this = (DMIMessage)Marshal.PtrToStructure(handler.AddrOfPinnedObject(), typeof(DMIMessage));
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
            return $"DMIMessage [{ActionId}@{StartAddress}:{EndAddress}]";
        }

        public readonly RenodeAction ActionId;
        public readonly byte Allowed;
        public readonly ulong StartAddress;
        public readonly ulong EndAddress;
        public readonly ulong MMFOffset;

        // TODO: 256 should be a named constant
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public byte[] MMFPath;
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
        }

        public ulong ReadQuadWord(long offset)
        {
            return Read(8, offset);
        }

        public void WriteRegister(byte dataLength, long offset, ulong value, byte connectionIndex = 0)
        {
            WriteInternal(RenodeAction.WriteRegister, dataLength, offset, value, connectionIndex);
        }

        public void Dispose()
        {
            if(systemcProcess != null && !systemcProcess.HasExited)
            {
                // Init message sent after connection has been established signifies Renode terminated and SystemC process
                // should exit.
                var request = new RenodeMessage(RenodeAction.Init, 0, 0, 0, 0);
                SendRequest(request, out var response);

                if(!systemcProcess.WaitForExit(500))
                {
                    this.Log(LogLevel.Info, "SystemC process failed to exit gracefully - killing it.");
                    systemcProcess.Kill();
                }
            }

            forwardSocket?.Close();
            backwardSocket?.Close();
        }

        public void Reset()
        {
            outGPIOState = 0;
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

            BitHelper.SetBit(ref outGPIOState, (byte)number, value);
            var request = new RenodeMessage(RenodeAction.GPIOWrite, 0, 0, 0, outGPIOState);
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

        public string SystemCExecutablePath
        {
            get => systemcExecutablePath;
            set
            {
                try
                {
                    systemcExecutablePath = value;
                    var listenerSocket = CreateListenerSocket(requestedPort);
                    var assignedPort = ((IPEndPoint)listenerSocket.LocalEndPoint).Port;
                    this.Log(LogLevel.Info, "SystemCPeripheral waiting for forward SystemC connection on {0}:{1}", address, assignedPort);
                    var connectionParams = $"{address} {assignedPort}";
                    StartSystemCProcess(systemcExecutablePath, connectionParams);
                    SetupConnection(listenerSocket);
                    SetupTimesync();
                }
                catch(Exception e)
                {
                    throw new RecoverableException($"Failed to start SystemC process: {e.Message}");
                }
            }
        }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

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

        private void StartSystemCProcess(string systemcExecutablePath, string connectionParams)
        {
            try
            {
#if !PLATFORM_WINDOWS
                Mono.Unix.Native.Syscall.chmod(systemcExecutablePath, FilePermissions.S_IRWXU);
#endif
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

        private Socket CreateListenerSocket(int requestedPort)
        {
            var listenerSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listenerSocket.Bind(new IPEndPoint(IPAddress.Parse(address), requestedPort));
            listenerSocket.Listen(2);
            return listenerSocket;
        }

        private void SetupConnection(Socket listenerSocket)
        {
            forwardSocket = listenerSocket.Accept();
            forwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for forwardSocket if the disableTimeoutCheck constructor argument is set - so if a debugger halts the SystemC process, Renode will wait for the process to restart
            if(!disableTimeoutCheck)
            {
                forwardSocket.ReceiveTimeout = 1000;
            }

            backwardSocket = listenerSocket.Accept();
            backwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for backwardSocket - it runs on a dedicated thread and by design blocks on Receive until a message arrives from SystemC process.

            listenerSocket.Close();

            SendRequest(new RenodeMessage(RenodeAction.Init, 0, 0, 0, (ulong)timeSyncPeriodUS), out var response);

            backwardThread.Start();
        }

        private void SetupTimesync()
        {
            // Timer unit is microseconds
            var timerName = "RenodeSystemCTimesyncTimer";
            var timesyncFrequency = 1000000;
            var timesyncLimit = (ulong)timeSyncPeriodUS;

            var timesyncTimer = new LimitTimer(machine.ClockSource, timesyncFrequency, this, timerName, limit: timesyncLimit, enabled: true, eventEnabled: true, autoUpdate: true);

            Action<TimeInterval, TimeInterval> adjustTimesyncToQuantum = ((_, newQuantum) =>
            {
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
                    SendRequest(request, out var response);
                });
            };
        }

        private bool SendRequest(RenodeMessage request, out RenodeMessage responseMessage)
        {
            lock(messageLock)
            {
                var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
                var recvBytes = new byte[messageSize];
                if(forwardSocket != null)
                {
                    forwardSocket.Send(request.Serialize(), SocketFlags.None);
                    forwardSocket.Receive(recvBytes, 0, messageSize, SocketFlags.None);

                    responseMessage = new RenodeMessage();
                    responseMessage.Deserialize(recvBytes);

                    return true;
                }
                else
                {
                    this.Log(LogLevel.Error, "Unable to communicate with SystemC peripheral. Try setting SystemCExecutablePath first.");
                    responseMessage = new RenodeMessage();
                    return false;
                }
            }
        }

        private void BackwardConnectionLoop()
        {
            while(true)
            {
                var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
                var recvBytes = new byte[messageSize];

                var nbytes = backwardSocket.Receive(recvBytes, 0, messageSize, SocketFlags.None);
                if(nbytes == 0)
                {
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
                    backwardSocket.Send(writeResponseMessage.Serialize(), SocketFlags.None);
                    break;
                case RenodeAction.Read:
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

                    backwardSocket.Send(readResponseMessage.Serialize(), SocketFlags.None);
                    break;
                case RenodeAction.DMIReq:
                    bool allowDMI = false;
                    var targetMemory = sysbus.FindMemory(message.Address);
                    if(targetMemory != null)
                    {
                        allowDMI = targetMemory.Peripheral.UsingSharedMemory;
                    }
                    long memBase = (long)(targetMemory.RegistrationPoint.Range.StartAddress + targetMemory.RegistrationPoint.Offset);
                    long memOffset = (long)message.Address - memBase;
                    ulong segmentStart = (ulong)memBase + (ulong)(memOffset - (memOffset % targetMemory.Peripheral.SegmentSize));
                    int segmentNo = 0;
                    if(allowDMI)
                    {
                        segmentNo = (int)(memOffset / targetMemory.Peripheral.SegmentSize);
                        allowDMI = segmentNo >= 0 && segmentNo < targetMemory.Peripheral.SegmentCount;
                    }
                    if(allowDMI)
                    {
                        // DMI allowed
                        var responseDMIMessage = new DMIMessage(
                                message.ActionId,
                                RenodeMessage.DMIAllowed,
                                segmentStart,
                                segmentStart + (ulong)targetMemory.Peripheral.SegmentSize - 1UL, // segment end
                                targetMemory.Peripheral.GetSegmentAlignmentOffset(segmentNo), // offset into the MMF corresponding to the segment start address
                                targetMemory.Peripheral.GetSegmentPath(segmentNo) // MMF path
                            );
                        backwardSocket.Send(responseDMIMessage.Serialize(), SocketFlags.None);
                    }
                    else
                    {
                        // DMI rejected
                        var responseDMIMessage = new DMIMessage(
                                message.ActionId,
                                RenodeMessage.DMINotAllowed,
                                0UL,
                                0UL,
                                0UL,
                                ""
                            );
                        backwardSocket.Send(responseDMIMessage.Serialize(), SocketFlags.None);
                    }
                    break;
                case RenodeAction.InvalidateTBs:
                    TryToInvalidateTBs(message.Address, message.Payload);
                    backwardSocket.Send(message.Serialize(), SocketFlags.None);
                    break;
                default:
                    this.Log(LogLevel.Error, "SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId);
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

        private Socket backwardSocket;

        private Socket forwardSocket;

        private ulong outGPIOState;
        private Process systemcProcess;
        private string systemcExecutablePath;

        private readonly Dictionary<int, IDirectAccessPeripheral> directAccessPeripherals;

        private readonly Thread backwardThread;
        private readonly bool disableTimeoutCheck;
        private readonly int requestedPort;

        private readonly string address;
        private readonly object messageLock;
        private readonly int timeSyncPeriodUS;

        private readonly IBusController sysbus;
        private readonly IMachine machine;

        // NumberOfGPIOPins must be equal to renode_bridge.h:NUM_GPIO
        private const int NumberOfGPIOPins = 64;
    }
}