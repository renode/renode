//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class SystemCCortexMSignalsUnit : SystemCPeripheral
    {
        public SystemCCortexMSignalsUnit(
                IMachine machine,
                CortexM cpu,
                string address,
                int port = 0,
                int timeSyncPeriodUS = 1000,
                bool disableTimeoutCheck = false)
             : base(machine,
                    address,
                    port,
                    timeSyncPeriodUS,
                    disableTimeoutCheck)
        {
            Connections[(int)Signal.CpuWait].Connect(cpu, (int)CortexM.CpuSignal.CpuWait);
        }

        public enum Signal
        {
            NonMaskableInterrupt = 0,           // nmi_exp
            CoreResetIn = 1,                    // core_reset_in
            CpuWait = 2,                        // cpu_wait
            InitNonSecureVectorTableOffset = 3, // init_ns_vtor
            InitSecureVectorTableOffset = 4,    // m55_initsvtor
            PowerOnReset = 5,                   // m55_poreset_n
            SystemResetRequest = 6,             // O_sysreset_req
            Sleeping = 7,                       // O_sleeping
            SleepDeep = 8,                      // O_sleep_deep
        }
    }
}
