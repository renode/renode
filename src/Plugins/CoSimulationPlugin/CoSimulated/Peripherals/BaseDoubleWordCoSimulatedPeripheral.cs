//
// Copyright (c) 2010-2024 Antmicro
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
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class BaseDoubleWordCoSimulatedPeripheral : CoSimulatedPeripheral, IDoubleWordPeripheral, IAbsoluteAddressAware
    {
        public BaseDoubleWordCoSimulatedPeripheral(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfInterrupts = 0)
            : base(machine, 32, frequency, simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS,
                simulationContextLinux, simulationContextWindows, simulationContextMacOS, limitBuffer, timeout, address, numberOfInterrupts)
        {
        }

        public override uint ReadDoubleWord(long offset)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot read from peripheral. Set SimulationFilePath or connect to a simulator first!");
                return 0;
            }
            Send(ActionType.ReadFromBus, UseAbsoluteAddress ? absoluteAddress : (ulong)offset, 0);
            var result = Receive();
            CheckValidation(result);

            return (uint)result.Data;
        }

        public override void WriteDoubleWord(long offset, uint value)
        {
            if(!IsConnected)
            {
                this.Log(LogLevel.Warning, "Cannot write to peripheral. Set SimulationFilePath or connect to a simulator first!");
                return;
            }
            Send(ActionType.WriteToBus, UseAbsoluteAddress ? absoluteAddress : (ulong)offset, value);
            CheckValidation(Receive());
        }

        public void SetAbsoluteAddress(ulong address)
        {
            this.absoluteAddress = address;
        }

        public bool UseAbsoluteAddress { get; set; }

        private ulong absoluteAddress;
    }
}
