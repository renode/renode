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

#nullable enable

namespace Antmicro.Renode.Peripherals.SystemC;

public abstract class SystemCCPUSignalsUnit : SystemCPeripheral, IExecutableIO
{
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

    protected SystemCCPUSignalsUnit(IMachine machine, string address, int port, int timeSyncPeriodUS, bool disableTimeoutCheck)
        : base(machine, address, port, timeSyncPeriodUS, disableTimeoutCheck)
    {
        bundledConnections = new Dictionary<uint, IReadOnlyDictionary<int, IGPIO>>();
    }

    protected IReadOnlyDictionary<int, IGPIO> RegisterCPU(ICPU cpu)
    {
        AddInitiator(cpu);
        var innerConnections = new Dictionary<int, IGPIO>();
        for(var i = 0; i < NumberOfGPIOPins; i++)
        {
            innerConnections[i] = new GPIO();
        }
        var connections = new ReadOnlyDictionary<int, IGPIO>(innerConnections);
        bundledConnections.Add(cpu.MultiprocessingId, connections);
        return connections;
    }

    protected void SetCpuClocked(ICPU cpu, bool value)
    {
        // The CPU cannot stop immediately. Wait for the current quantum to
        // finish, when no memory transactions are in progress.
        machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
        {
            cpu.Clocked = value;
        }, true);
    }

    protected void ScheduleReset(ICPU cpu, bool isAsserted, Action reset)
    {
        if(isAsserted)
        {
            SetDeferredHalt(cpu, true);
        }

        // Reset may trigger bus accesses or outgoing GPIOs. Running it on
        // the backward connection thread can deadlock if the forward socket
        // is waiting for TimeSync, so defer it to a synchronized state.
        machine.LocalTimeSource.ExecuteInNearestSyncedState(_ =>
        {
            SetDeferredHalt(cpu, false);
            if(isAsserted)
            {
                cpu.IsHalted = true;
                this.DebugLog("CPU halted after reset signal assertion");
            }
            else
            {
                // The caller resets the CPU and its associated peripherals,
                // including any architecture-specific halting conditions.
                reset();
                // Ensure the CPU is resumed after the implicit pause on reset.
                cpu.Resume();
                this.DebugLog("CPU and peripherals were reset after signal deassertion");
            }
        }, true);
    }

    protected override void HandleGpioWrite(int number, bool value, uint initiatorId)
    {
        var connections = bundledConnections[initiatorId];
        connections[number].Set(value);
    }

    private readonly Dictionary<uint, IReadOnlyDictionary<int, IGPIO>> bundledConnections;

    protected class GPIOHandler : IGPIOReceiver
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
