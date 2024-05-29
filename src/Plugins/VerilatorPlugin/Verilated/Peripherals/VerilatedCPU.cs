//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Threading;
using System.Collections.Generic;
using System.Collections.Concurrent;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using Antmicro.Renode.Peripherals.CPU.Disassembler;
using Antmicro.Renode.Peripherals.CPU.Registers;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Time;
using ELFSharp.ELF;
using ELFSharp.UImage;
using Machine = Antmicro.Renode.Core.Machine;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public abstract class VerilatedCPU : BaseCPU, IGPIOReceiver, ITimeSink, IDisposable
    {
        public VerilatedCPU(string cpuType, Machine machine, Endianess endianness, CpuBitness bitness = CpuBitness.Bits32, 
            string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null,
            string simulationContextLinux = null, string simulationContextWindows = null, string simulationContextMacOS = null, string address = null)
            : base(0, cpuType, machine, endianness, bitness)
        {
            verilatedPeripheral = new BaseVerilatedPeripheral(simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS,
                simulationContextLinux, simulationContextWindows, simulationContextMacOS, BaseVerilatedPeripheral.DefaultTimeout, address);
            verilatedPeripheral.OnReceive = HandleReceived;

            InitializeRegisters();
        }

        public override void Start()
        {
            base.Start();
            if(!String.IsNullOrWhiteSpace(verilatedPeripheral.SimulationFilePath))
            {
                verilatedPeripheral.Start();
            }
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

            lock(verilatedPeripheralLock)
            {
                verilatedPeripheral.Reset();
            }
        }

        public override void Dispose()
        {
            base.Dispose();
            lock(verilatedPeripheralLock)
            {
                verilatedPeripheral.Dispose();
            }
        }

        public void OnGPIO(int number, bool value)
        {
            this.NoisyLog("IRQ {0}, value {1}", number, value);
            if(!IsStarted)
            {
                return;
            }
            lock(verilatedPeripheralLock)
            {
                verilatedPeripheral.Send(ActionType.Interrupt, (ulong)number, (ulong)(value ? 1 : 0));
            }
        }

        public virtual void SetRegisterValue32(int register, uint value)
        {
            lock(verilatedPeripheralLock)
            {
                setRegisterValue = false;
                verilatedPeripheral.Send(ActionType.RegisterSet, (ulong)register, (ulong) value);
                while(!setRegisterValue) // This kind of while loops are for socket communication
                {
                    verilatedPeripheral.HandleMessage();
                }
            }
        }

        public virtual uint GetRegisterValue32(int register)
        {
            lock(verilatedPeripheralLock)
            {
                gotRegisterValue = false;
                verilatedPeripheral.Send(ActionType.RegisterGet, (ulong)register, 0);
                while(!gotRegisterValue)
                {
                    verilatedPeripheral.HandleMessage();
                }
                return (uint)registerValue;
            }
        }

        public override ExecutionResult ExecuteInstructions(ulong numberOfInstructionsToExecute, out ulong numberOfExecutedInstructions)
        {
            instructionsExecutedThisRound = 0UL;

            try
            {
                lock(verilatedPeripheralLock)
                {
                    if (IsSingleStepMode)
                    {
                        while(instructionsExecutedThisRound < 1)
                        {
                            gotStep = false;
                            verilatedPeripheral.Send(ActionType.Step, 0, 1);
                            while(!gotStep)
                            {
                                verilatedPeripheral.HandleMessage();
                            }
                        }
                    }
                    else
                    {
                        ticksProcessed = false;
                        verilatedPeripheral.Send(ActionType.TickClock, 0, numberOfInstructionsToExecute);
                        while(!ticksProcessed)
                        {
                            verilatedPeripheral.HandleMessage();
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

        protected abstract void InitializeRegisters();

        public override ExecutionMode ExecutionMode
        {
            get
            {
                return executionMode;
            }

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

                    lock(verilatedPeripheralLock)
                    {
                        switch(executionMode)
                        {
                            case ExecutionMode.Continuous:
                                verilatedPeripheral.Send(ActionType.SingleStepMode, 0, 0);
                                break;
                            case ExecutionMode.SingleStep:
                                verilatedPeripheral.Send(ActionType.SingleStepMode, 0, 1);
                                break;
                        }

                        while(!gotSingleStepMode)
                        {
                            verilatedPeripheral.HandleMessage();
                        }
                    }

                    singleStepSynchronizer.Enabled = IsSingleStepMode;
                    UpdateHaltedState();
                }
            }
        }

        public override ulong ExecutedInstructions => totalExecutedInstructions;

        protected void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.PushByte:
                    this.NoisyLog("Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteByte(message.Address, (byte)message.Data);
                    break;
                case ActionType.PushWord:
                    this.NoisyLog("Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteWord(message.Address, (ushort)message.Data);
                    break;
                case ActionType.PushDoubleWord:
                    this.Log(LogLevel.Noisy, "Writing data: 0x{0:X} to address: 0x{1:X}", message.Data, message.Address);
                    machine.SystemBus.WriteDoubleWord(message.Address, (uint)message.Data);
                    break;
                case ActionType.GetDoubleWord:
                    this.Log(LogLevel.Noisy, "Requested data from address: 0x{0:X}", message.Address);
                    var data = machine.SystemBus.ReadDoubleWord(message.Address);
                    lock(verilatedPeripheralLock)
                    {
                        verilatedPeripheral.Respond(ActionType.WriteToBus, 0, data);
                    }
                    break;
                case ActionType.TickClock:
                    ticksProcessed = true;
                    instructionsExecutedThisRound = message.Data;
                    break;
                case ActionType.IsHalted:
                    isHaltedRequested = message.Data > 0 ? true : false;
                    this.NoisyLog("isHaltedRequested: {0}", isHaltedRequested);
                    break;
                case ActionType.RegisterGet:
                    gotRegisterValue = true;
                    registerValue = message.Data;
                    break;
                case ActionType.RegisterSet:
                    setRegisterValue = true;
                    break;
                case ActionType.SingleStepMode:
                    gotSingleStepMode = true;
                    break;
                case ActionType.Step:
                    gotStep = true;
                    instructionsExecutedThisRound = message.Data;
                    break;
                default:
                    this.Log(LogLevel.Warning, "Unhandled message: ActionId = {0}; Address: 0x{1:X}; Data: 0x{2:X}!",
                        message.ActionId, message.Address, message.Data);
                    break;
            }
        }

        public string SimulationFilePathLinux
        {
            get
            {
                return SimulationFilePath;
            }
            set
            {
#if PLATFORM_LINUX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathWindows
        {
            get
            {
                return SimulationFilePath;
            }
            set
            {
#if PLATFORM_WINDOWS
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathMacOS
        {
            get
            {
                return SimulationFilePath;
            }
            set
            {
#if PLATFORM_OSX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePath
        {
            get
            {
                return verilatedPeripheral.SimulationFilePath;
            }
            set
            {
                if(!String.IsNullOrWhiteSpace(value))
                {
                    verilatedPeripheral.SimulationFilePath = value;
                    verilatedPeripheral.Start();
                }
            }
        }

        protected readonly object verilatedPeripheralLock = new object();

        private readonly BaseVerilatedPeripheral verilatedPeripheral;

        private bool gotRegisterValue;
        private ulong registerValue;
        private bool setRegisterValue;
        private bool gotSingleStepMode;
        private bool gotStep;
        private ulong instructionsExecutedThisRound;
        private ulong totalExecutedInstructions;
        private bool ticksProcessed;
    }
}
