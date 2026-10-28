//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Collections.ObjectModel;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.IRQControllers;
using Antmicro.Renode.Peripherals.IRQControllers.PLIC;

#nullable enable

namespace Antmicro.Renode.Peripherals.SystemC;

public class RiscVBundle
{
    public RiscVBundle(
        BaseRiscV cpu,
        IIRQController? interruptController = null,
        IHasFrequency? timer = null,
        ulong bootAddress = 0x1000,
        int? numberOfInterrupts = null,
        ulong? nmiVectorAddress = null,
        uint? nmiVectorLength = null,
        SignalActiveWhen resetInActive = SignalActiveWhen.High
    )
    {
        // Direct inputs address bits in mip, whose width follows the CPU.
        var maximumInterrupts = interruptController == null ? (int)cpu.PC.Bits : (int)SystemCRiscVSignalsUnit.Signal.NonMaskableInterrupt;
        var interruptCount = numberOfInterrupts ?? (interruptController == null ? maximumInterrupts : 64);
        if(interruptCount < 0 || interruptCount > maximumInterrupts)
        {
            throw new ConstructionException($"Invalid number of interrupt inputs: {interruptCount}. Expected a value between 0 and {maximumInterrupts}.");
        }

        Cpu = cpu;
        InterruptController = interruptController;
        Timer = timer;
        BootAddress = bootAddress;
        NumberOfInterrupts = interruptCount;
        ResetInActive = resetInActive;

        Cpu.ResetVector = bootAddress;

        if(nmiVectorAddress.HasValue)
        {
            Cpu.NMIVectorAddress = nmiVectorAddress;
        }
        if(nmiVectorLength.HasValue)
        {
            Cpu.NMIVectorLength = nmiVectorLength;
        }
    }

    public BaseRiscV Cpu { get; }

    public IIRQController? InterruptController { get; }

    public IHasFrequency? Timer { get; }

    public int NumberOfInterrupts { get; }

    public SignalActiveWhen ResetInActive { get; }

    public ulong BootAddress { get; set; }

    public ulong ClockFrequency { get; set; }

    public bool ResetInAsserted { get; set; }
}

public class SystemCRiscVSignalsUnit : SystemCCPUSignalsUnit
{
    public SystemCRiscVSignalsUnit(
            IMachine machine,
            RiscVBundle[] riscvBundles,
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
        var riscvBundleMap = new Dictionary<uint, RiscVBundle>();
        foreach(var riscvBundle in riscvBundles)
        {
            var id = riscvBundle.Cpu.MultiprocessingId;

            riscvBundleMap.Add(id, riscvBundle);
            var connections = RegisterCPU(riscvBundle.Cpu);
            SetupRiscVBundle(riscvBundle, connections);
        }
        this.riscvBundles = new ReadOnlyDictionary<uint, RiscVBundle>(riscvBundleMap);
    }

    // NOTE: Don't send anything via the `forwardSocket` from the background connection thread.
    //       This may lead to deadlocks, as SystemC blocks waiting for a response from this thread.
    protected override void OnUnhandledRenodeMessage(RenodeMessage message)
    {
        switch(message.ActionId)
        {
        case RenodeAction.SetBootAddress:
        {
            var riscvBundle = riscvBundles[message.InitiatorId];
            HandleSetBootAddress(riscvBundle, message.Address);
            SendBackwardResponse(message);
            this.NoisyLog("SystemC boot address set to 0x{0:X} for initiator {1}", message.Address, message.InitiatorId);
            break;
        }
        case RenodeAction.SetClockFrequency:
        {
            var riscvBundle = riscvBundles[message.InitiatorId];
            HandleSetClockFrequency(riscvBundle, message.Address);
            SendBackwardResponse(message);
            this.NoisyLog("Clock frequency set to {0} for initiator {1}", message.Address, message.InitiatorId);
            break;
        }
        default:
            this.ErrorLog("SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId);
            break;
        }
    }

    private void HandleSetBootAddress(RiscVBundle riscvBundle, ulong bootAddress)
    {
        var cpu = riscvBundle.Cpu;

        riscvBundle.BootAddress = bootAddress;

        // The boot address is sampled at reset, but Renode doesn't treat
        // the emulation start as a reset. Set the PC immediately so that
        // SystemC can select the boot address before the CPU starts.
        if(!cpu.IsStarted)
        {
            cpu.ResetVector = bootAddress;
            cpu.PC = bootAddress;
            return;
        }

        // ResetVector can also update PC after a CPU reset. Preserve the
        // current PC at a sync point to avoid racing execution.
        machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
        {
            var pc = cpu.PC;
            cpu.ResetVector = bootAddress;
            cpu.PC = pc;
        }, true);
    }

    private void HandleSetClockFrequency(RiscVBundle riscvBundle, ulong clockFrequency)
    {
        if(clockFrequency != 0)
        {
            SetClockFrequency(riscvBundle, clockFrequency);
            SetCpuClocked(riscvBundle.Cpu, true);
        }
        else
        {
            riscvBundle.ClockFrequency = 0;
            SetCpuClocked(riscvBundle.Cpu, false);
        }
    }

    private void SetClockFrequency(RiscVBundle riscvBundle, ulong value)
    {
        riscvBundle.ClockFrequency = value;
        if(riscvBundle.Timer != null)
        {
            riscvBundle.Timer.Frequency = value;
        }
    }

    private void SetupRiscVBundle(RiscVBundle riscvBundle, IReadOnlyDictionary<int, IGPIO> connections)
    {
        var cpu = riscvBundle.Cpu;
        var interruptController = riscvBundle.InterruptController;
        var resetInActive = riscvBundle.ResetInActive;

        // PLIC sources are numbered from 1, source 0 is reserved.
        var firstIrq = interruptController is IPlatformLevelInterruptController ? 1 : 0;
        for(var irq = firstIrq; irq < riscvBundle.NumberOfInterrupts; irq++)
        {
            if(interruptController != null)
            {
                connections[irq].Connect(interruptController, irq);
            }
            else
            {
                connections[irq].Connect(cpu, irq);
            }
        }

        connections[(int)Signal.NonMaskableInterrupt].Connect(
            new GPIOHandler((state) => HandleNonMaskableInterrupt(riscvBundle, state)), 0);
        connections[(int)Signal.Reset].Connect(
            new GPIOHandler((state) => ResetCpuAndPeripherals(riscvBundle, connections, state, resetInActive)), 0);
    }

    private void HandleNonMaskableInterrupt(RiscVBundle riscvBundle, bool state)
    {
        if(riscvBundle.Cpu is ICPUWithNMI cpuWithNmi)
        {
            cpuWithNmi.OnNMI(0, state, null);
        }
        else
        {
            this.WarningLog("Non-maskable interrupts are not supported by {0}", riscvBundle.Cpu.GetType().Name);
        }
    }

    private void ResetCpuAndPeripherals(RiscVBundle riscvBundle, IReadOnlyDictionary<int, IGPIO> connections, bool state, SignalActiveWhen resetOn)
    {
        var cpu = riscvBundle.Cpu;
        var interruptController = riscvBundle.InterruptController;
        var timer = riscvBundle.Timer;

        void resetAndLeaveReset()
        {
            cpu.Reset();
            interruptController?.Reset();
            (timer as IPeripheral)?.Reset();

            // Reset clears pending interrupts, but SystemC inputs keep their
            // levels. GPIO.Set would suppress an unchanged level, so restore
            // asserted inputs directly on the receivers.
            var firstIrq = interruptController is IPlatformLevelInterruptController ? 1 : 0;
            for(var irq = firstIrq; irq < riscvBundle.NumberOfInterrupts; irq++)
            {
                if(connections[irq].IsSet)
                {
                    ((interruptController as IGPIOReceiver) ?? cpu).OnGPIO(irq, true);
                }
            }
            if(connections[(int)Signal.NonMaskableInterrupt].IsSet)
            {
                HandleNonMaskableInterrupt(riscvBundle, true);
            }
            cpu.IsHalted = false;
        }

        var resetState = resetOn == SignalActiveWhen.High ? true : false;
        var isAsserted = state == resetState;
        if(riscvBundle.ResetInAsserted == isAsserted)
        {
            return;
        }
        riscvBundle.ResetInAsserted = isAsserted;

        ScheduleReset(cpu, isAsserted, resetAndLeaveReset);
    }

    private readonly IReadOnlyDictionary<uint, RiscVBundle> riscvBundles;

    public enum Signal
    {
        InterruptsStart = 0,                   // irq[0]
        InterruptsEnd = 4095,                  // irq[4095]
        NonMaskableInterrupt = 4096,           // nmi
        Reset = 4097,                          // reset
    }
}
