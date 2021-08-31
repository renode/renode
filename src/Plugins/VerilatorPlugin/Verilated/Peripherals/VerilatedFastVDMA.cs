//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Peripherals.Verilated
{
    [AllowedTranslations(AllowedTranslation.ByteToDoubleWord)]
    public class VerilatedFastVDMA : BaseDoubleWordVerilatedPeripheral
    {
        public VerilatedFastVDMA(Machine machine, long frequency, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string address = null) : base(machine, frequency, simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS, limitBuffer, timeout, address)
        {
            IRQ = new GPIO();
        }

        public GPIO IRQ { get; }

        protected override void HandleInterrupt(ProtocolMessage interrupt)
        {
            switch((VerliatedFastVDMAInterrupt)interrupt.Address)
            {
                case VerliatedFastVDMAInterrupt.Writer:
                case VerliatedFastVDMAInterrupt.Reader:
                    IRQ.Set(interrupt.Data != 0);
                    break;
                default:
                    base.HandleInterrupt(interrupt);
                    break;
            }
        }

        private enum VerliatedFastVDMAInterrupt : ulong
        {
            Writer = 0,
            Reader = 1
        }
    }
}
