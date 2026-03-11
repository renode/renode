//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.IRQControllers;
using Antmicro.Renode.Peripherals.Miscellaneous;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class SystemCCortexMSignalsUnit : SystemCPeripheral
    {
        public SystemCCortexMSignalsUnit(
                IMachine machine,
                CortexM cpu,
                NVIC nvic,
                string address,
                int port = 0,
                int timeSyncPeriodUS = 1000,
                bool disableTimeoutCheck = false,
                DWT dwt = null,
                SignalActiveWhen powerOnResetActive = SignalActiveWhen.High)
             : base(machine,
                    address,
                    port,
                    timeSyncPeriodUS,
                    disableTimeoutCheck)
        {
            this.cpu = cpu;
            this.nvic = nvic;
            this.dwt = dwt;
            this.powerOnResetActive = powerOnResetActive;

            Connections[(int)Signal.CpuWait].Connect(cpu, (int)CortexM.CpuSignal.CpuWait);

            // This signal is by default treated as active-HIGH, even though the source signal 'nPORESET' is active-LOW
            Connections[(int)Signal.PowerOnReset].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(state, powerOnResetActive)), 0);
        }

        private void ResetCpuAndPeripherals(bool state, SignalActiveWhen resetOn)
        {
            var resetState = resetOn == SignalActiveWhen.High ? true : false;
            if(state != resetState)
            {
                return;
            }

            cpu.Reset();
            nvic.Reset();
            dwt?.Reset();
            Connections[(int)Signal.PowerOnReset].Unset();
        }

        private readonly CortexM cpu;
        private readonly NVIC nvic;
        private readonly DWT dwt;
        private readonly SignalActiveWhen powerOnResetActive;

        public enum SignalActiveWhen
        {
            Low,
            High,
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

        private class GPIOHandler : IGPIOReceiver
        {
            public GPIOHandler(Action<bool> handler, bool resetValue = false)
            {
                this.handler = handler;
                this.resetValue = resetValue;
            }

            public void OnGPIO(int number, bool value)
            {
                handler(value);
            }

            public void Reset()
            {
                handler(resetValue);
            }

            private readonly bool resetValue;
            private readonly Action<bool> handler;
        }
    }
}
