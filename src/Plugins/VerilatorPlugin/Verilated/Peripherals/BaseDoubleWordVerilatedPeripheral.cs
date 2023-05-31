//
// Copyright (c) 2010-2023 Antmicro
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
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class BaseDoubleWordVerilatedPeripheral : VerilatedPeripheral, IDoubleWordPeripheral, IAbsoluteAddressAware
    {
        public BaseDoubleWordVerilatedPeripheral(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null, int numberOfInterrupts = 0)
            : base(machine, 4, frequency, simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS,
                simulationContextLinux, simulationContextWindows, simulationContextMacOS, limitBuffer, timeout, address, numberOfInterrupts)
        {
        }
    }
}
