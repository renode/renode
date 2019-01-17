//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Diagnostics;
using System.Threading;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class BasePeripheral : IDoubleWordPeripheral, IDisposable
    {
        public BasePeripheral(Machine machine, string filePath, long frequency, ulong limit)
        {
            mainSocket = new Socket();
            receiverSocket = new ReceiverSocket();
            InitVerilatedProcess(filePath, mainSocket.Port, receiverSocket.Port);
            InitTimer(machine.ClockSource, frequency, limit);

            receiveThread = new Thread(Receive);
            receiveThread.IsBackground = true;
            receiveThread.Name = $"Verilated.Receiver";
            receiveThread.Start();
        }

        public uint ReadDoubleWord(long offset)
        {
            mainSocket.Send(GetProtocol(ActionNumber.ReadFromBus, (ulong)offset, 0));
            return (uint)mainSocket.Receive().Data;
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            mainSocket.Send(GetProtocol(ActionNumber.WriteToBus, (ulong)offset, value));
        }

        public void Receive()
        {
            while(true)
            {
                HandleReceived(receiverSocket.Receive());
            }
        }

        public void Reset()
        {
            mainSocket.Send(GetProtocol(ActionNumber.ResetPeripheral, 0, 0));
        }

        public void Dispose()
        {
            receiveThread.Abort();
            mainSocket.Send(GetProtocol(ActionNumber.Disconnect, 0, 0));
            mainSocket.Disconnect();
            receiverSocket.Disconnect();
        }

        protected virtual void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionNumber.LogMessage:
                    var logLevel = BitConverter.ToInt32(receiverSocket.ReceiveBytes(), 0);
                    this.Log((LogLevel)logLevel, receiverSocket.ReceiveString());
                    break;
                case ActionNumber.Interrupt:
                    HandleInterrupt(message);
                    break;
            }
        }

        protected virtual void HandleInterrupt(ProtocolMessage interrupt)
        {
            this.Log(LogLevel.Info, $"Unhandled interrupt: {interrupt.Address}");
        }

        protected ProtocolMessage GetProtocol(ActionNumber actionId, ulong address, ulong value)
        {
            var result = new ProtocolMessage
            {
                ActionId = actionId,
                Address = address,
                Data = value
            };
            return result;
        }

        protected Socket mainSocket;
        protected ReceiverSocket receiverSocket;

        private void InitTimer(IClockSource clockSource, long frequency, ulong limit)
        {
            timer = new LimitTimer(clockSource, frequency, limit, enabled: true, eventEnabled: true, autoUpdate: true);
            timer.LimitReached += () =>
            {
                mainSocket.Send(GetProtocol(ActionNumber.TickClock, 0, limit));
            };
        }

        private void InitVerilatedProcess(string filePath, int mainPort, int receiverPort)
        {
            try
            {
                verilatedProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(filePath, $"{mainPort} {receiverPort}")
                    {
                        UseShellExecute = false
                    }
                };
                verilatedProcess.Start();
            }
            catch(Exception ex)
            {
                throw new ConstructionException(ex.Message);
            }
        }

        private LimitTimer timer;
        private Thread receiveThread;
        private Process verilatedProcess;
    }
}
