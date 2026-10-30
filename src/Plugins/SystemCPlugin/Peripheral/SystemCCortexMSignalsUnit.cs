//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.IRQControllers;
using Antmicro.Renode.Peripherals.Miscellaneous;

using Signal = Antmicro.Renode.Peripherals.SystemC.SystemCCortexMSignalsUnit.Signal;

#nullable enable

namespace Antmicro.Renode.Peripherals.SystemC
{
    public class CortexMBundle : CPUSignalsBundle<CortexM>
    {
        public CortexMBundle(
            CortexM cpu,
            NVIC nvic,
            DWT? dwt = null,
            SignalActiveWhen powerOnResetActive = SignalActiveWhen.High,
            SignalActiveWhen coreResetInActive = SignalActiveWhen.High
        )
            : base(cpu)
        {
            Nvic = nvic;
            Dwt = dwt;
            PowerOnResetActive = powerOnResetActive;
            CoreResetInActive = coreResetInActive;
        }

        public override void Setup(SystemCCPUSignalsUnit unit, IReadOnlyDictionary<int, IGPIO> connections)
        {
            var cpu = Cpu;
            var nvic = Nvic;
            var powerOnResetActive = PowerOnResetActive;
            var coreResetInActive = CoreResetInActive;
            var id = cpu.MultiprocessingId;

            // Initialize state to the same initial value as on the CPU side.
            // It is guaranteed that CPU constructor was already executed,
            // because it's a dependency of this constructor.
            connections[(int)Signal.CpuWait].Set(cpu.CpuWaitSignal.IsSet);
            connections[(int)Signal.CpuWait].Connect(cpu, (int)CortexM.CpuSignal.CpuWait);
            for(var irq = (int)Signal.NvicIrqsStart; irq <= (int)Signal.NvicIrqsEnd; irq++)
            {
                connections[(int)Signal.NvicIrqsStart + irq].Connect(nvic, irq);
            }

            /*
             * These signals are by default treated as active-HIGH,
             * even though the source signals 'nPORESET' and 'nSYSRESET' are active-LOW.
             */
            connections[(int)Signal.PowerOnReset].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(unit, Signal.PowerOnReset, state, powerOnResetActive)), 0);
            connections[(int)Signal.CoreResetIn].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(unit, Signal.CoreResetIn, state, coreResetInActive)), 0);

            // NVIC's OnGPIO adds an offset to skip over system exceptions, so we need to subtract it.
            connections[(int)Signal.NonMaskableInterrupt].Connect(nvic, NmiException - SystemExceptionOffset);

            nvic.SystemResetRequest.Connect(new GPIOHandler((state) => unit.SendGpioUpdateFromBundle((int)Signal.SystemResetRequest, state, id)), 0);
            nvic.InSleep.Connect(new GPIOHandler((state) => unit.SendGpioUpdateFromBundle((int)Signal.Sleeping, state, id)), 0);
            nvic.InDeepSleep.Connect(new GPIOHandler((state) => unit.SendGpioUpdateFromBundle((int)Signal.SleepDeep, state, id)), 0);
            nvic.Lockup.Connect(new GPIOHandler((state) => unit.SendGpioUpdateFromBundle((int)Signal.Lockup, state, id)), 0);
        }

        public override bool HandleMessage(SystemCCPUSignalsUnit unit, RenodeMessage message)
        {
            switch(message.ActionId)
            {
            case RenodeAction.InitSecureVTOR:
            {
                var vectorTableOffset = (uint)message.Address;
                HandleInitSecureVTOR(unit, vectorTableOffset);
                unit.NoisyLog("SystemC Vector Table Offset: 0x{0:X}", vectorTableOffset);
                return true;
            }
            case RenodeAction.InitNonSecureVTOR:
            {
                var vectorTableOffsetNonSecure = (uint)message.Address;
                HandleInitNonSecureVTOR(vectorTableOffsetNonSecure);
                unit.NoisyLog("SystemC Non Secure Vector Table Offset: 0x{0:X}", vectorTableOffsetNonSecure);
                return true;
            }
            case RenodeAction.SetClockFrequency:
            {
                var clockFrequency = (uint)message.Address;
                HandleSetClockFrequency(unit, clockFrequency);
                unit.NoisyLog("Clock frequency set to {0} for initiator {1}", clockFrequency, message.InitiatorId);
                return true;
            }
            default:
                return false;
            }
        }

        public NVIC Nvic { get; }

        public DWT? Dwt { get; }

        public SignalActiveWhen PowerOnResetActive { get; }

        public SignalActiveWhen CoreResetInActive { get; }

        public bool PowerOnResetAsserted { get; set; }

        public bool CoreResetInAsserted { get; set; }

        public bool VtorInitialized { get; set; }

        public bool VtorNonSecureInitialized { get; set; }

        private void HandleInitSecureVTOR(SystemCCPUSignalsUnit unit, uint vectorTableOffset)
        {
            var cpu = Cpu;

            if(!cpu.TrustZoneEnabled)
            {
                unit.WarningLog("The Security Extension is not enabled. Ignoring Secure Vector table offset signal");
                return;
            }

            // The INITSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
            // Therefore, we need to manually set the VTOR immediately
            // in order to allow SystemC to set the VTOR before the CPU starts.
            if(!VtorInitialized && !cpu.IsStarted)
            {
                if(!cpu.SecureState)
                {
                    throw new InvalidOperationException("CPU must be in the secure state on initialization");
                }
                cpu.VectorTableOffset = vectorTableOffset;
            }

            VtorInitialized = true;
            cpu.InitVectorTableOffset = vectorTableOffset;
        }

        private void HandleInitNonSecureVTOR(uint vectorTableOffsetNonSecure)
        {
            var cpu = Cpu;

            /*
            * When security extensions are not enabled, we treat the `VectorTableOffset`
            * property as the nonsecure vector table offset register.
            */

            // The INITNSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
            // Therefore, we need to manually set the VTOR immediately
            // in order to allow SystemC to set the VTOR before the CPU starts.
            if(!VtorNonSecureInitialized && !cpu.IsStarted)
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

            VtorNonSecureInitialized = true;
        }

        private void HandleSetClockFrequency(SystemCCPUSignalsUnit unit, uint clockFrequency)
        {
            if(clockFrequency != 0)
            {
                SetClockFrequency(clockFrequency);
                SetClockedState(unit, true);
            }
            else
            {
                SetClockedState(unit, false);
            }
        }

        private void SetClockFrequency(ulong value)
        {
            Nvic.Frequency = value;
            if(Dwt != null)
            {
                Dwt.Frequency = value;
            }
        }

        private void SetClockedState(SystemCCPUSignalsUnit unit, bool value)
        {
            Nvic.Clocked = value;
            if(Dwt != null)
            {
                Dwt.Clocked = value;
            }

            unit.SetCpuClocked(Cpu, value);
        }

        private void ResetCpuAndPeripherals(SystemCCPUSignalsUnit unit, Signal signal, bool state, SignalActiveWhen resetOn)
        {
            var resetState = resetOn == SignalActiveWhen.High ? true : false;
            var wasAsserted = CoreResetInAsserted || PowerOnResetAsserted;
            if(state == resetState)
            {
                switch(signal)
                {
                case Signal.CoreResetIn:
                    CoreResetInAsserted = true;
                    break;
                case Signal.PowerOnReset:
                    PowerOnResetAsserted = true;
                    break;
                default:
                    return;
                }
            }
            else
            {
                switch(signal)
                {
                case Signal.CoreResetIn:
                    CoreResetInAsserted = false;
                    break;
                case Signal.PowerOnReset:
                    PowerOnResetAsserted = false;
                    break;
                default:
                    return;
                }
            }
            var isAsserted = CoreResetInAsserted || PowerOnResetAsserted;

            if(wasAsserted == isAsserted)
            {
                return;
            }

            unit.ScheduleReset(Cpu, isAsserted, () =>
            {
                // CPUWAIT is preserved by CortexM.Reset() and keeps the CPU halted
                // until CPUWAIT is deasserted.
                Cpu.Reset();
                Nvic.Reset();
                Dwt?.Reset();
            });
        }

        private const int NmiException = 2;
        private const int SystemExceptionOffset = 16;
    }

    public class SystemCCortexMSignalsUnit : SystemCCPUSignalsUnit
    {
        public SystemCCortexMSignalsUnit(
                IMachine machine,
                CortexMBundle[] cortexMBundles,
                string address = "127.0.0.1",
                int port = 0,
                int timeSyncPeriodUS = 1000,
                bool disableTimeoutCheck = false
            )
             : base(machine,
                    cortexMBundles,
                    address,
                    port,
                    timeSyncPeriodUS,
                    disableTimeoutCheck)
        {
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
            Lockup = 1009,                         // O_lockup
        }
    }
}
