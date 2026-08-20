//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.IRQControllers;
using Antmicro.Renode.Peripherals.Miscellaneous;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public enum SignalActiveWhen
    {
        Low,
        High,
    }

    public class CortexMBundle
    {
        public CortexMBundle(
            CortexM cpu,
            NVIC nvic,
            DWT dwt = null,
            SignalActiveWhen powerOnResetActive = SignalActiveWhen.High,
            SignalActiveWhen coreResetInActive = SignalActiveWhen.High
        )
        {
            Cpu = cpu;
            Nvic = nvic;
            Dwt = dwt;
            PowerOnResetActive = powerOnResetActive;
            CoreResetInActive = coreResetInActive;
        }

        public CortexM Cpu { get; }

        public NVIC Nvic { get; }

        public DWT Dwt { get; }

        public SignalActiveWhen PowerOnResetActive { get; }

        public SignalActiveWhen CoreResetInActive { get; }

        public bool PowerOnResetAsserted { get; set; }

        public bool CoreResetInAsserted { get; set; }

        public bool VtorInitialized { get; set; }

        public bool VtorNonSecureInitialized { get; set; }
    }

    public class SystemCCortexMSignalsUnit : SystemCPeripheral, IExecutableIO
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
                    address,
                    port,
                    timeSyncPeriodUS,
                    disableTimeoutCheck)
        {
            var cortexMBundleMap = new Dictionary<uint, CortexMBundle>();
            var bundledConnections = new Dictionary<uint, IReadOnlyDictionary<int, IGPIO>>();
            foreach(var cortexMBundle in cortexMBundles)
            {
                var id = cortexMBundle.Cpu.MultiprocessingId;

                var innerConnections = new Dictionary<int, IGPIO>();
                for(var i = 0; i < NumberOfGPIOPins; i++)
                {
                    innerConnections[i] = new GPIO();
                }
                var connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);
                bundledConnections.Add(id, connections);
                cortexMBundleMap.Add(id, cortexMBundle);
                SetupCortexMBundle(cortexMBundle, connections);
            }
            this.cortexMBundles = new ReadOnlyDictionary<uint, CortexMBundle>(cortexMBundleMap);
            this.bundledConnections = new ReadOnlyDictionary<uint, IReadOnlyDictionary<int, IGPIO>>(bundledConnections);
        }

        /// <remarks>
        /// CPU is allowed to execute code from this peripheral,
        /// so it implements <see cref="IMemory"/> via <see cref="IExecutableIO"/>.
        /// Nevertheless this peripheral isn't required to represent a uniform memory space at SystemC side
        /// and it usually covers multiple peripherals on the remote side,
        /// but the particular memory layout is transparent to this peripheral. 
        /// So in general this peripheral shouldn't be treated as a pure memory
        /// and extension methods like DumpBinary should be used with caution,
        /// as all accesses are redirected to the SystemC implementation.
        /// Anyway we try to provide a reasonable default for <see cref="IKnownSize.Size"/>
        /// spanning the whole registered area on the system bus.
        /// As we use the information from the registration point,
        /// <see cref="IKnownSize.Size"/> can't be used for the registration itself,
        /// so <see cref="BusRangeRegistration"/> must be always used instead of <see cref="BusPointRegistration"/>.
        /// Failing to do so will report exception during construction.
        /// </remarks>
        public long Size
        {
            get
            {
                try
                {
                    return (long)
                    this.GetMachine()
                        .GetSystemBus(this)
                        .GetRegistrationPoints(this)
                        .First()
                        .Range.Size;
                }
                catch(Exception)
                {
                    throw new RecoverableException("Unable to detect size from the registration point");
                }
            }
        }

        protected override void HandleGpioWrite(int number, bool value, uint initiatorId)
        {
            var connections = bundledConnections[initiatorId];
            connections[number].Set(value);
        }

        // NOTE: Don't send anything via the `forwardSocket` from the background connection thread.
        //       This may lead to deadlocks, as SystemC blocks waiting for a response from this thread.
        protected override void OnUnhandledRenodeMessage(RenodeMessage message)
        {
            switch(message.ActionId)
            {
            case RenodeAction.InitSecureVTOR:
            {
                var cortexMBundle = cortexMBundles[message.InitiatorId];
                var vectorTableOffset = (uint)message.Address;
                HandleInitSecureVTOR(cortexMBundle, vectorTableOffset);
                SendBackwardResponse(message);
                this.NoisyLog("SystemC Vector Table Offset: 0x{0:X}", vectorTableOffset);
                break;
            }
            case RenodeAction.InitNonSecureVTOR:
            {
                var cortexMBundle = cortexMBundles[message.InitiatorId];
                var vectorTableOffsetNonSecure = (uint)message.Address;
                HandleInitNonSecureVTOR(cortexMBundle, vectorTableOffsetNonSecure);
                SendBackwardResponse(message);
                this.NoisyLog("SystemC Non Secure Vector Table Offset: 0x{0:X}", vectorTableOffsetNonSecure);
                break;
            }
            default:
                this.ErrorLog("SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId);
                break;
            }
        }

        private void HandleInitSecureVTOR(CortexMBundle cortexMBundle, uint vectorTableOffset)
        {
            var cpu = cortexMBundle.Cpu;

            if(!cpu.TrustZoneEnabled)
            {
                this.WarningLog("The Security Extension is not enabled. Ignoring Secure Vector table offset signal");
                return;
            }

            // The INITSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
            // Therefore, we need to manually set the VTOR immediately
            // in order to allow SystemC to set the VTOR before the CPU starts.
            if(!cortexMBundle.VtorInitialized && !cpu.IsStarted)
            {
                if(!cpu.SecureState)
                {
                    throw new InvalidOperationException("CPU must be in the secure state on initialization");
                }
                cpu.VectorTableOffset = vectorTableOffset;
            }

            cortexMBundle.VtorInitialized = true;
            cpu.InitVectorTableOffset = vectorTableOffset;
        }

        private void HandleInitNonSecureVTOR(CortexMBundle cortexMBundle, uint vectorTableOffsetNonSecure)
        {
            var cpu = cortexMBundle.Cpu;

            /*
            * When security extensions are not enabled, we treat the `VectorTableOffset`
            * property as the nonsecure vector table offset register.
            */

            // The INITNSVTOR is sampled at resets, but Renode doesn't treat the emulation start as a reset.
            // Therefore, we need to manually set the VTOR immediately
            // in order to allow SystemC to set the VTOR before the CPU starts.
            if(!cortexMBundle.VtorNonSecureInitialized && !cpu.IsStarted)
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

            cortexMBundle.VtorNonSecureInitialized = true;
        }

        private void SetupCortexMBundle(CortexMBundle cortexMBundle, IReadOnlyDictionary<int, IGPIO> connections)
        {
            var cpu = cortexMBundle.Cpu;
            var nvic = cortexMBundle.Nvic;
            var dwt = cortexMBundle.Dwt;
            var powerOnResetActive = cortexMBundle.PowerOnResetActive;
            var coreResetInActive = cortexMBundle.CoreResetInActive;
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
            connections[(int)Signal.PowerOnReset].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(cortexMBundle, Signal.PowerOnReset, state, powerOnResetActive)), 0);
            connections[(int)Signal.CoreResetIn].Connect(new GPIOHandler((state) => ResetCpuAndPeripherals(cortexMBundle, Signal.CoreResetIn, state, coreResetInActive)), 0);

            // NVIC's OnGPIO adds an offset to skip over system exceptions, so we need to subtract it.
            connections[(int)Signal.NonMaskableInterrupt].Connect(nvic, NmiException - SystemExceptionOffset);

            nvic.SystemResetRequest.Connect(new GPIOHandler((state) => SendGpioUpdate((int)Signal.SystemResetRequest, state, id)), 0);
            nvic.InSleep.Connect(new GPIOHandler((state) => SendGpioUpdate((int)Signal.Sleeping, state, id)), 0);
            nvic.InDeepSleep.Connect(new GPIOHandler((state) => SendGpioUpdate((int)Signal.SleepDeep, state, id)), 0);
            nvic.Lockup.Connect(new GPIOHandler((state) => SendGpioUpdate((int)Signal.Lockup, state, id)), 0);
        }

        private void ResetCpuAndPeripherals(CortexMBundle cortexMBundle, Signal signal, bool state, SignalActiveWhen resetOn)
        {
            var cpu = cortexMBundle.Cpu;
            var nvic = cortexMBundle.Nvic;
            var dwt = cortexMBundle.Dwt;

            void holdInReset()
            {
                cpu.IsHalted = true;
                this.DebugLog("Cpu halted after reset signal assertion");
            }

            void resetAndLeaveReset()
            {
                cpu.Reset();
                nvic.Reset();
                dwt?.Reset();
                // Ensure cpu is resumed after implicit pause on cpu reset.
                // CPUWAIT is preserved by CortexM.Reset() and keeps the CPU halted
                // until CPUWAIT is deasserted.
                cpu.Resume();
                this.DebugLog("Cpu and peripherals were reset after signal deassertion");
            }

            var resetState = resetOn == SignalActiveWhen.High ? true : false;
            var wasAsserted = cortexMBundle.CoreResetInAsserted || cortexMBundle.PowerOnResetAsserted;
            if(state == resetState)
            {
                switch(signal)
                {
                case Signal.CoreResetIn:
                    cortexMBundle.CoreResetInAsserted = true;
                    break;
                case Signal.PowerOnReset:
                    cortexMBundle.PowerOnResetAsserted = true;
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
                    cortexMBundle.CoreResetInAsserted = false;
                    break;
                case Signal.PowerOnReset:
                    cortexMBundle.PowerOnResetAsserted = false;
                    break;
                default:
                    return;
                }
            }
            var isAsserted = cortexMBundle.CoreResetInAsserted || cortexMBundle.PowerOnResetAsserted;

            if(wasAsserted == isAsserted)
            {
                return;
            }

            void updateResetState()
            {
                if(isAsserted)
                {
                    holdInReset();
                }
                else
                {
                    resetAndLeaveReset();
                }
            }

            if(DisableSidebandChannel)
            {
                // Reset asynchronously, because there is no sideband channel.
                // GPIO signal (PowerOnReset/CoreResetIn) from SystemC
                // can trigger either bus access to SystemC (read PC and SP from VTOR offset)
                // or assert GPIO signal from Renode -> SystemC.
                // If forward socket is blocking on TimeSync,
                // it causes a deadlock, so defer it.
                machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
                {
                    updateResetState();
                }, true);
            }
            else
            {
                // Reset synchronously. Sideband channel can handle nested requests.
                updateResetState();
            }
        }

        private readonly IReadOnlyDictionary<uint, CortexMBundle> cortexMBundles;
        private readonly IReadOnlyDictionary<uint, IReadOnlyDictionary<int, IGPIO>> bundledConnections;
        private const int NmiException = 2;
        private const int SystemExceptionOffset = 16;

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
