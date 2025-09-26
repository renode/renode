//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;
using Antmicro.Renode.Time;

using ELFSharp.ELF;

using Machine = Antmicro.Renode.Core.Machine;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public abstract class CoSimulatedCPU : BaseCPU, IGPIOReceiver, ICoSimulationConnectible, ITimeSink, IDisposable
    {
        public CoSimulatedCPU(string cpuType, Machine machine, Endianess endianness, CpuBitness bitness = CpuBitness.Bits32, string address = null)
            : base(0, cpuType, machine, endianness, bitness)
        {
            // Multiple CoSimulatedCPUs per CoSimulationConnection are currently not supported.
            RenodeToCosimIndex = 0;
            CosimToRenodeIndex = 0;

            cosimConnection = new CoSimulationConnection(machine, "cpu_cosim_cosimConnection", 0,
                        0, 0, address, 0, 0);
            cosimConnection.AttachTo(this);

            InitializeRegisters();
        }

        public override void Reset()
        {
            base.Reset();

            gotRegisterValue = false;
            setRegisterValue = false;
            gotSingleStepMode = false;
            ticksProcessed = false;
            gotStep = false;

            registerValue = 0;
            instructionsExecutedThisRound = 0;
            totalExecutedInstructions = 0;

            lock(cosimConnectionLock)
            {
                cosimConnection.Reset();
            }
        }

        public override void Dispose()
        {
            base.Dispose();
            lock(cosimConnectionLock)
            {
                cosimConnection.Dispose();
            }
        }

        public void OnGPIO(int number, bool value)
        {
            if(!cosimConnection.IsConnected)
            {
                this.NoisyLog("OnGPIO for IRQ {number}, value {value} will have no effect, because co-simulation is not connected.");
                return;
            }
            this.NoisyLog("IRQ {0}, value {1}", number, value);
            lock(cosimConnectionLock)
            {
                cosimConnection.Send(this, ActionType.Interrupt, (ulong)number, (ulong)(value ? 1 : 0));
            }
        }

        public virtual void SetRegisterValue32(int register, uint value)
        {
            lock(cosimConnectionLock)
            {
                setRegisterValue = false;
                cosimConnection.Send(this, ActionType.RegisterSet, (ulong)register, (ulong)value);
                while(!setRegisterValue) // This kind of while loops are for socket communication
                {
                    cosimConnection.HandleMessage();
                }
            }
        }

        public virtual uint GetRegisterValue32(int register)
        {
            lock(cosimConnectionLock)
            {
                gotRegisterValue = false;
                cosimConnection.Send(this, ActionType.RegisterGet, (ulong)register, 0);
                while(!gotRegisterValue)
                {
                    cosimConnection.HandleMessage();
                }
                return (uint)registerValue;
            }
        }

        public override ExecutionResult ExecuteInstructions(ulong numberOfInstructionsToExecute, out ulong numberOfExecutedInstructions)
        {
            instructionsExecutedThisRound = 0UL;

            try
            {
                lock(cosimConnectionLock)
                {
                    if(IsSingleStepMode)
                    {
                        while(instructionsExecutedThisRound < 1)
                        {
                            gotStep = false;
                            cosimConnection.Send(this, ActionType.Step, 0, 1);
                            while(!gotStep)
                            {
                                cosimConnection.HandleMessage();
                            }
                        }
                    }
                    else
                    {
                        ticksProcessed = false;
                        cosimConnection.Send(this, ActionType.TickClock, 0, numberOfInstructionsToExecute);
                        while(!ticksProcessed)
                        {
                            cosimConnection.HandleMessage();
                        }
                    }
                }
            }
            catch(Exception)
            {
                this.NoisyLog("CPU exception detected, halting.");
                InvokeHalted(new HaltArguments(HaltReason.Abort, this));
                return ExecutionResult.Aborted;
            }
            finally
            {
                numberOfExecutedInstructions = instructionsExecutedThisRound;
                totalExecutedInstructions += instructionsExecutedThisRound;
            }

            return ExecutionResult.Ok;
        }

        public virtual void OnConnectionAttached(CoSimulationConnection connection)
        {
            cosimConnection.OnReceive += HandleReceived;
        }

        public virtual void OnConnectionDetached(CoSimulationConnection connection)
        {
            cosimConnection.OnReceive -= HandleReceived;
        }

        public string SimulationFilePathLinux
        {
            get => SimulationFilePath;
            set
            {
#if PLATFORM_LINUX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathWindows
        {
            get => SimulationFilePath;
            set
            {
#if PLATFORM_WINDOWS
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathMacOS
        {
            get => SimulationFilePath;
            set
            {
#if PLATFORM_OSX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePath
        {
            get => cosimConnection.SimulationFilePath;
            set
            {
                if(!String.IsNullOrWhiteSpace(value))
                {
                    cosimConnection.SimulationFilePath = value;
                }
            }
        }

        public int RenodeToCosimIndex { get; }

        public int CosimToRenodeIndex { get; }

        public override ExecutionMode ExecutionMode
        {
            get => executionMode;
            set
            {
                lock(singleStepSynchronizer.Guard)
                {
                    if(executionMode == value)
                    {
                        return;
                    }

                    executionMode = value;

                    gotSingleStepMode = false;
                    lock(cosimConnectionLock)
                    {
                        switch(executionMode)
                        {
                        case ExecutionMode.Continuous:
                            cosimConnection.Send(this, ActionType.SingleStepMode, 0, 0);
                            break;
                        case ExecutionMode.SingleStep:
                            cosimConnection.Send(this, ActionType.SingleStepMode, 0, 1);
                            break;
                        }

                        while(!gotSingleStepMode)
                        {
                            cosimConnection.HandleMessage();
                        }
                    }

                    singleStepSynchronizer.Enabled = IsSingleStepMode;
                    UpdateHaltedState();
                }
            }
        }

        public override ulong ExecutedInstructions => totalExecutedInstructions;

        protected bool HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
            case ActionType.TickClock:
                ticksProcessed = true;
                instructionsExecutedThisRound = message.Data;
                return true;
            case ActionType.IsHalted:
                isHaltedRequested = message.Data > 0 ? true : false;
                this.NoisyLog("isHaltedRequested: {0}", isHaltedRequested);
                return true;
            case ActionType.RegisterGet:
                registerValue = message.Data;
                gotRegisterValue = true;
                return true;
            case ActionType.RegisterSet:
                setRegisterValue = true;
                return true;
            case ActionType.SingleStepMode:
                gotSingleStepMode = true;
                return true;
            case ActionType.Step:
                gotStep = true;
                instructionsExecutedThisRound = message.Data;
                return true;
            default:
                break;
            }

            return false;
        }

        protected abstract void InitializeRegisters();

        protected readonly object cosimConnectionLock = new object();

        private ulong registerValue;

        private bool gotRegisterValue;
        private bool setRegisterValue;
        private bool gotSingleStepMode;
        private bool gotStep;
        private ulong instructionsExecutedThisRound;
        private ulong totalExecutedInstructions;
        private bool ticksProcessed;

        private readonly CoSimulationConnection cosimConnection;
    }
}