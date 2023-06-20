//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class VerilatedPeripheral : BaseVerilatedPeripheral, IQuadWordPeripheral, IDoubleWordPeripheral, IWordPeripheral, IBytePeripheral, IBusPeripheral, IDisposable, IHasOwnLife, INumberedGPIOOutput, IAbsoluteAddressAware
    {
        public VerilatedPeripheral(Machine machine, long frequency, uint maxWidth, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfInterrupts = 0)
            : base(simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS, timeout, address)
        {
            this.machine = machine;
            allTicksProcessedARE = new AutoResetEvent(initialState: false);
            this.OnReceive = HandleReceivedMessage;
            this.maxWidth = maxWidth;

            timer = new LimitTimer(machine.ClockSource, frequency, this, LimitTimerName, limitBuffer, enabled: true, eventEnabled: true, autoUpdate: true);
            timer.LimitReached += () =>
            {
                if(!verilatorConnection.TrySendMessage(new ProtocolMessage(ActionType.TickClock, 0, limitBuffer)))
                {
                    AbortAndLogError("Send error!");
                }
                this.NoisyLog("Tick: TickClock sent, waiting for the verilated peripheral...");
                allTicksProcessedARE.WaitOne();
                this.NoisyLog("Tick: Verilated peripheral finished evaluating the model.");
            };

            var innerConnections = new Dictionary<int, IGPIO>();
            for(int i = 0; i < numberOfInterrupts; i++)
            {
                innerConnections[i] = new GPIO();
            }

            Connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);
        }

        public override void Reset()
        {
            base.Reset();
            timer.Reset();
        }

        public virtual byte ReadByte(long offset)
        {
            if(!VerifyLength(1, offset))
            {
                return 0;
            }
            return (byte)Read(ActionType.ReadFromBusByte, offset);
        }

        public virtual ushort ReadWord(long offset)
        {
            if(!VerifyLength(2, offset))
            {
                return 0;
            }
            return (ushort)Read(ActionType.ReadFromBusWord, offset);
        }

        public virtual uint ReadDoubleWord(long offset)
        {
            if(!VerifyLength(4, offset))
            {
                return 0;
            }
            return (uint)Read(ActionType.ReadFromBusDoubleWord, offset);
        }

        public virtual ulong ReadQuadWord(long offset)
        {
            if(!VerifyLength(8, offset))
            {
                return 0;
            }
            return Read(ActionType.ReadFromBusQuadWord, offset);
        }

        public virtual void WriteByte(long offset, byte value)
        {
            if(VerifyLength(1, offset, value))
            {
                Write(ActionType.WriteToBusByte, offset, value);
            }
        }

        public virtual void WriteWord(long offset, ushort value)
        {
            if(VerifyLength(2, offset, value))
            {
                Write(ActionType.WriteToBusWord, offset, value);
            }
        }

        public virtual void WriteDoubleWord(long offset, uint value)
        {
            if(VerifyLength(4, offset, value))
            {
                Write(ActionType.WriteToBusDoubleWord, offset, value);
            }
        }

        public virtual void WriteQuadWord(long offset, ulong value)
        {
            if(VerifyLength(8, offset, value))
            {
                Write(ActionType.WriteToBusQuadWord, offset, value);
            }
        }

        public override void HandleReceivedMessage(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.InvalidAction:
                    this.Log(LogLevel.Warning, "Invalid action received");
                    break;
                case ActionType.Interrupt:
                    HandleInterrupt(message);
                    break;
                case ActionType.PushByte:
                    this.Log(LogLevel.Noisy, "Writing byte: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteByte(message.Address, (byte)message.Data);
                    break;
                case ActionType.PushWord:
                    this.Log(LogLevel.Noisy, "Writing word: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteWord(message.Address, (ushort)message.Data);
                    break;
                case ActionType.PushDoubleWord:
                    this.Log(LogLevel.Noisy, "Writing dword: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteDoubleWord(message.Address, (uint)message.Data);
                    break;
                case ActionType.PushQuadWord:
                    this.Log(LogLevel.Noisy, "Writing qword: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteQuadWord(message.Address, message.Data);
                    break;
                case ActionType.GetDoubleWord:
                    var data = machine.SystemBus.ReadDoubleWord(message.Address);
                    this.Log(LogLevel.Noisy, "Requested dword from address: 0x{0:X}, read 0x{1:X}", message.Address, data);
                    Respond(ActionType.WriteToBusDoubleWord, 0, data);
                    break;
                case ActionType.GetQuadWord:
                    var quadData = machine.SystemBus.ReadQuadWord(message.Address);
                    this.Log(LogLevel.Info, "Requested qword from address: 0x{0:X}, read 0x{1:X}", message.Address, quadData);
                    Respond(ActionType.WriteToBusQuadWord, 0, quadData);
                    break;
                case ActionType.TickClock:
                    allTicksProcessedARE.Set();
                    break;
                default:
                    this.Log(LogLevel.Warning, "Unhandled message: ActionId = {0}; Address: 0x{1:X}; Data: 0x{2:X}!",
                        message.ActionId, message.Address, message.Data);
                    break;
            }
        }

        public void SetAbsoluteAddress(ulong address)
        {
            this.absoluteAddress = address;
        }

        public bool UseAbsoluteAddress { get; set; }

        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        protected bool VerifyLength(int length, long offset, ulong? value = null)
        {
            if(length > maxWidth)
            {
                this.Log(LogLevel.Warning, "Trying to {0} {1} bits at offset 0x{2:X}{3}, but maximum length is {4}",
                        value.HasValue ? "write" : "read",
                        length,
                        offset,
                        value.HasValue ? $" (value 0x{value})" : String.Empty,
                        maxWidth
                );
                return false;
            }
            return true;
        }

        protected void Write(ActionType type, long offset, ulong value)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot write to peripheral. Set SimulationFilePath or connect to a simulator first!");
                return;
            }
            if(!alignmentInitialized)
            {
                alignmentInitialized = true;
                Send(ActionType.SetAccessAlignment, 0, maxWidth);
            }
            Send(type, UseAbsoluteAddress ? absoluteAddress : (ulong)offset, value);
            CheckValidation(Receive());
        }

        protected ulong Read(ActionType type, long offset)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot read from peripheral. Set SimulationFilePath or connect to a simulator first!");
                return 0;
            }
            if(!alignmentInitialized)
            {
                alignmentInitialized = true;
                Send(ActionType.SetAccessAlignment, 0, maxWidth);
            }
            Send(type, UseAbsoluteAddress ? absoluteAddress : (ulong)offset, 0);
            var result = Receive();
            CheckValidation(result);

            return result.Data;
        }

        protected override void HandleInterrupt(ProtocolMessage interrupt)
        {
            if (!Connections.TryGetValue((int)interrupt.Address, out var connection))
            {
                this.Log(LogLevel.Warning, "Unhandled interrupt: '{0}'", interrupt.Address);
                return;
            }

            connection.Set(interrupt.Data != 0);
        }

        // does not need to be reset, as width is effectively a constructor parameter
        private bool alignmentInitialized;

        protected readonly Machine machine;
        protected readonly uint maxWidth;

        protected const ulong LimitBuffer = 1000000;

        private readonly AutoResetEvent allTicksProcessedARE;
        private readonly LimitTimer timer;
        private ulong absoluteAddress;
        private const string LimitTimerName = "VerilatorIntegrationClock";
    }
}
