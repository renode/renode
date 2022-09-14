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
    public class VerilatedPeripheral : BaseVerilatedPeripheral, IBusPeripheral, IDisposable, IHasOwnLife, INumberedGPIOOutput
    {
        public VerilatedPeripheral(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfInterrupts = 0)
            : base(simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS, timeout, address)
        {
            this.machine = machine;
            allTicksProcessedARE = new AutoResetEvent(initialState: false);
            this.OnReceive = HandleReceivedMessage;

            timer = new LimitTimer(machine.ClockSource, frequency, this, LimitTimerName, limitBuffer, enabled: false, eventEnabled: true, autoUpdate: true);
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

            timer.Enabled = true;

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
                    this.Log(LogLevel.Noisy, "Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteByte(message.Address, (byte)message.Data);
                    break;
                case ActionType.PushWord:
                    this.Log(LogLevel.Noisy, "Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteWord(message.Address, (ushort)message.Data);
                    break;
                case ActionType.PushDoubleWord:
                    this.Log(LogLevel.Noisy, "Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteDoubleWord(message.Address, (uint)message.Data);
                    break;
                case ActionType.GetDoubleWord:
                    this.Log(LogLevel.Noisy, "Requested data from address: 0x{0:X}", message.Address);
                    var data = machine.SystemBus.ReadDoubleWord(message.Address);
                    Respond(ActionType.WriteToBus, 0, data);
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
        
        public IReadOnlyDictionary<int, IGPIO> Connections { get; }

        protected override void HandleInterrupt(ProtocolMessage interrupt)
        {
            if (!Connections.TryGetValue((int)interrupt.Address, out var connection))
            {
                this.Log(LogLevel.Warning, "Unhandled interrupt: '{0}'", interrupt.Address);
                return;
            }

            connection.Set(interrupt.Data != 0);
        }
        
        protected readonly Machine machine;

        protected const ulong LimitBuffer = 1000000;

        private readonly AutoResetEvent allTicksProcessedARE;
        private readonly LimitTimer timer;
        private const string LimitTimerName = "VerilatorIntegrationClock";
    }
}
