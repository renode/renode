//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.Bus;
using System.Collections.Generic;
// using InternalCortexMContextState =  Antmicro.Renode.Peripherals.CPU.InternalCortexMContextState;

namespace Antmicro.Renode.Peripherals.CPU
{
    public class SampleStateAwareReaderWithTransactionState : IPeripheralWithTransactionState, IBusPeripheral
    {
        public SampleStateAwareReaderWithTransactionState(Machine machine)
        {
            sysbus = machine.GetSystemBus(this);
        }

        public void Reset()
        {
        }

        public uint Read(ulong address, ulong state)
        {
            return sysbus.ReadDoubleWord(address, context: this, cpuState: state);
        }

        public uint ReadUsingStateObj(ulong address)
        {
            if(!TryConvertUlongToStateObj(0, out var contextState))
            {
                return 0;
            }
            return sysbus.ReadDoubleWordWithState(address, this, contextState);
        }

        public bool TryConvertStateObjToUlong(IContextState stateObj, out ulong? state)
        {
            state = null;
            if((stateObj == null) || !(stateObj is CortexM.ContextState cpuStateObj))
            {
                return false;
            }
            state = 0u;
            state |= (cpuStateObj.Privileged ? 1u : 0) & 1u;
            state |= (cpuStateObj.CpuSecure ? 2u : 0) & 2u;
            state |= (cpuStateObj.AttributionSecure ? 4u : 0) & 4u;
            return true;
        }

        public bool TryConvertUlongToStateObj(ulong? state, out IContextState stateObj)
        {
            stateObj = null;
            if(!state.HasValue)
            {
                return false;
            }
            var cpuStateObj = new CortexM.ContextState
            {
                Privileged = (state & 1u) == 1u,
                CpuSecure = (state & 2u) == 2u,
                AttributionSecure = (state & 4u) == 4u
            };
            stateObj = cpuStateObj;
            return true;
        }

        public IReadOnlyDictionary<string, int> StateBits { get { return stateBits; } }

        private static readonly IReadOnlyDictionary<string, int> stateBits = new Dictionary<string, int>
        {
            ["privileged"] = 0,
            ["cpuSecure"] = 1,
            ["attributionSecure"] = 2,
        };

        private IBusController sysbus;
    }
}
