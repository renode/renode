//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Net.Sockets;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
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
                SignalActiveWhen powerOnResetActive = SignalActiveWhen.High,
                SignalActiveWhen coreResetInActive = SignalActiveWhen.High)
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
            this.coreResetInActive = coreResetInActive;

            // Initialize state to the same initial value as on the CPU side.
            // It is guaranteed that CPU constructor was already executed,
            // because it's a dependency of this constructor.
            Connections[(int)Signal.CpuWait].Set(cpu.CpuWaitSignal.IsSet);
            Connections[(int)Signal.CpuWait].Connect(cpu, (int)CortexM.CpuSignal.CpuWait);
            for(var irq = (int)Signal.NvicIrqsStart; irq <= (int)Signal.NvicIrqsEnd; irq++)
            {
                Connections[(int)Signal.NvicIrqsStart + irq].Connect(nvic, irq);
            }

            /*
             * These signals are by default treated as active-HIGH,
             * even though the source signals 'nPORESET' and 'nSYSRESET' are active-LOW.
             */
            Connections[(int)Signal.PowerOnReset].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(state, powerOnResetActive)), 0);
            Connections[(int)Signal.CoreResetIn].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(state, coreResetInActive)), 0);

            // NVIC's OnGPIO adds an offset to skip over system exceptions, so we need to subtract it.
            Connections[(int)Signal.NonMaskableInterrupt].Connect(nvic, NmiException - SystemExceptionOffset);

            nvic.SystemResetRequest.Connect(this, (int)Signal.SystemResetRequest);
            nvic.InSleep.Connect(this, (int)Signal.Sleeping);
            nvic.InDeepSleep.Connect(this, (int)Signal.SleepDeep);
        }

        protected override void OnUnhandledRenodeMessage(RenodeMessage message)
        {
            switch(message.ActionId)
            {
            case RenodeAction.InitSecureVTOR:
                var vectorTableOffset = (uint)message.Address;

                if(!cpu.TrustZoneEnabled)
                {
                    this.WarningLog("The Security Extension is not enabled. Ignoring Secure Vector table offset signal");
                    backwardSocket.Send(message.Serialize(), SocketFlags.None);
                    break;
                }

                // The INITSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
                // Therefore, we need to manually set the VTOR immediately
                // in order to allow SystemC to set the VTOR before the CPU starts.
                if(!vtorInitialized && !cpu.IsStarted)
                {
                    if(!cpu.SecureState)
                    {
                        throw new InvalidOperationException("CPU must be in the secure state on initialization");
                    }
                    cpu.VectorTableOffset = vectorTableOffset;
                }

                vtorInitialized = true;
                cpu.InitVectorTableOffset = vectorTableOffset;
                backwardSocket.Send(message.Serialize(), SocketFlags.None);
                this.NoisyLog("SystemC Vector Table Offset: 0x{0:X}", vectorTableOffset);
                break;
            case RenodeAction.InitNonSecureVTOR:
                var vectorTableOffsetNonSecure = (uint)message.Address;

                /*
                 * When security extensions are not enabled, we treat the `VectorTableOffset`
                 * property as the nonsecure vector table offset register.
                 */

                // The INITNSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
                // Therefore, we need to manually set the VTOR immediately
                // in order to allow SystemC to set the VTOR before the CPU starts.
                if(!vtorNonSecureInitialized && !cpu.IsStarted)
                {
                    if(cpu.TrustZoneEnabled)
                    {
                        cpu.VectorTableOffsetNonSecure = vectorTableOffsetNonSecure;
                    }
                    else
                    {
                        cpu.VectorTableOffset = vectorTableOffsetNonSecure;
                    }
                }

                if(cpu.TrustZoneEnabled)
                {
                    cpu.InitVectorTableOffsetNonSecure = vectorTableOffsetNonSecure;
                }
                else
                {
                    cpu.InitVectorTableOffset = vectorTableOffsetNonSecure;
                }

                vtorNonSecureInitialized = true;
                backwardSocket.Send(message.Serialize(), SocketFlags.None);
                this.NoisyLog("SystemC Non Secure Vector Table Offset: 0x{0:X}", vectorTableOffsetNonSecure);
                break;
            default:
                this.ErrorLog("SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId);
                break;
            }
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
        }

        private bool vtorInitialized = false;
        private bool vtorNonSecureInitialized = false;
        private readonly CortexM cpu;
        private readonly NVIC nvic;
        private readonly DWT dwt;
        private readonly SignalActiveWhen powerOnResetActive;
        private readonly SignalActiveWhen coreResetInActive;
        private const int NmiException = 2;
        private const int SystemExceptionOffset = 16;

        public enum SignalActiveWhen
        {
            Low,
            High,
        }

        public enum Signal
        {
            NvicIrqsStart = 0,                     // int_rq[0]
            NvicIrqsEnd = 479,                     // int_rq[479]
            NonMaskableInterrupt = 1000,           // nmi_exp
            CoreResetIn = 1001,                    // core_reset_in
            CpuWait = 1002,                        // cpu_wait
            PowerOnReset = 1005,                   // m55_poreset_n
            SystemResetRequest = 1006,             // O_sysreset_req
            Sleeping = 1007,                       // O_sleeping
            SleepDeep = 1008,                      // O_sleep_deep
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
