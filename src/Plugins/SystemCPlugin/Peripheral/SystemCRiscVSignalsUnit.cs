//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.IRQControllers;
using Antmicro.Renode.Peripherals.IRQControllers.PLIC;

using Signal = Antmicro.Renode.Peripherals.SystemC.SystemCRiscVSignalsUnit.Signal;

#nullable enable

namespace Antmicro.Renode.Peripherals.SystemC;

public class RiscVBundle : CPUSignalsBundle<BaseRiscV>
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
        : base(cpu)
    {
        // Direct inputs address bits in mip, whose width follows the CPU.
        var maximumInterrupts = interruptController == null ? (int)cpu.PC.Bits : (int)SystemCRiscVSignalsUnit.Signal.NonMaskableInterrupt;
        var interruptCount = numberOfInterrupts ?? (interruptController == null ? maximumInterrupts : 64);
        if(interruptCount < 0 || interruptCount > maximumInterrupts)
        {
            throw new ConstructionException($"Invalid number of interrupt inputs: {interruptCount}. Expected a value between 0 and {maximumInterrupts}.");
        }

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

    public override void Setup(SystemCCPUSignalsUnit unit, IReadOnlyDictionary<int, IGPIO> connections)
    {
        // PLIC sources are numbered from 1, source 0 is reserved.
        var firstIrq = InterruptController is IPlatformLevelInterruptController ? 1 : 0;
        for(var irq = firstIrq; irq < NumberOfInterrupts; irq++)
        {
            if(InterruptController != null)
            {
                connections[irq].Connect(InterruptController, irq);
            }
            else
            {
                connections[irq].Connect(Cpu, irq);
            }
        }

        connections[(int)Signal.NonMaskableInterrupt].Connect(
            new GPIOHandler((state) => HandleNonMaskableInterrupt(unit, state)), 0);
        connections[(int)Signal.Reset].Connect(
            new GPIOHandler((state) => ResetCpuAndPeripherals(unit, connections, state, ResetInActive)), 0);
    }

    public override bool HandleMessage(SystemCCPUSignalsUnit unit, RenodeMessage message)
    {
        switch(message.ActionId)
        {
        case RenodeAction.SetBootAddress:
        {
            HandleSetBootAddress(unit, message.Address);
            unit.NoisyLog("SystemC boot address set to 0x{0:X} for initiator {1}", message.Address, message.InitiatorId);
            return true;
        }
        case RenodeAction.SetClockFrequency:
        {
            HandleSetClockFrequency(unit, message.Address);
            unit.NoisyLog("Clock frequency set to {0} for initiator {1}", message.Address, message.InitiatorId);
            return true;
        }
        default:
            return false;
        }
    }

    public IIRQController? InterruptController { get; }

    public IHasFrequency? Timer { get; }

    public int NumberOfInterrupts { get; }

    public SignalActiveWhen ResetInActive { get; }

    public ulong BootAddress { get; set; }

    public ulong ClockFrequency { get; set; }

    public bool ResetInAsserted { get; set; }

    private void HandleSetBootAddress(SystemCCPUSignalsUnit unit, ulong bootAddress)
    {
        BootAddress = bootAddress;

        // The boot address is sampled at reset, but Renode doesn't treat
        // the emulation start as a reset. Set the PC immediately so that
        // SystemC can select the boot address before the CPU starts.
        if(!Cpu.IsStarted)
        {
            Cpu.ResetVector = bootAddress;
            Cpu.PC = bootAddress;
            return;
        }

        // ResetVector can also update PC after a CPU reset. Preserve the
        // current PC at a sync point to avoid racing execution.
        unit.ExecuteInNearestSyncedState(() =>
        {
            var pc = Cpu.PC;
            Cpu.ResetVector = bootAddress;
            Cpu.PC = pc;
        });
    }

    private void HandleSetClockFrequency(SystemCCPUSignalsUnit unit, ulong clockFrequency)
    {
        if(clockFrequency != 0)
        {
            SetClockFrequency(clockFrequency);
            unit.SetCpuClocked(Cpu, true);
        }
        else
        {
            ClockFrequency = 0;
            unit.SetCpuClocked(Cpu, false);
        }
    }

    private void SetClockFrequency(ulong value)
    {
        ClockFrequency = value;
        if(Timer != null)
        {
            Timer.Frequency = value;
        }
    }

    private void HandleNonMaskableInterrupt(SystemCCPUSignalsUnit unit, bool state)
    {
        if(Cpu is ICPUWithNMI cpuWithNmi)
        {
            cpuWithNmi.OnNMI(0, state, null);
        }
        else
        {
            unit.WarningLog("Non-maskable interrupts are not supported by {0}", Cpu.GetType().Name);
        }
    }

    private void ResetCpuAndPeripherals(SystemCCPUSignalsUnit unit, IReadOnlyDictionary<int, IGPIO> connections, bool state, SignalActiveWhen resetOn)
    {
        void resetAndLeaveReset()
        {
            Cpu.Reset();
            InterruptController?.Reset();
            (Timer as IPeripheral)?.Reset();

            // Reset clears pending interrupts, but SystemC inputs keep their
            // levels. GPIO.Set would suppress an unchanged level, so restore
            // asserted inputs directly on the receivers.
            var firstIrq = InterruptController is IPlatformLevelInterruptController ? 1 : 0;
            for(var irq = firstIrq; irq < NumberOfInterrupts; irq++)
            {
                if(connections[irq].IsSet)
                {
                    ((InterruptController as IGPIOReceiver) ?? Cpu).OnGPIO(irq, true);
                }
            }
            if(connections[(int)Signal.NonMaskableInterrupt].IsSet)
            {
                HandleNonMaskableInterrupt(unit, true);
            }
            Cpu.IsHalted = false;
        }

        var resetState = resetOn == SignalActiveWhen.High ? true : false;
        var isAsserted = state == resetState;
        if(ResetInAsserted == isAsserted)
        {
            return;
        }
        ResetInAsserted = isAsserted;

        unit.ScheduleReset(Cpu, isAsserted, resetAndLeaveReset);
    }
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
                riscvBundles,
                address,
                port,
                timeSyncPeriodUS,
                disableTimeoutCheck)
    {
    }

    public enum Signal
    {
        InterruptsStart = 0,                   // irq[0]
        InterruptsEnd = 4095,                  // irq[4095]
        NonMaskableInterrupt = 4096,           // nmi
        Reset = 4097,                          // reset
    }
}
