//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Threading;
using System.Runtime.InteropServices;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.CFU;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Binding;
using Antmicro.Renode.Core.Structure;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public class CFUVerilatedPeripheral : ICFU, IDisposable, IHasOwnLife
    {
        public CFUVerilatedPeripheral(Machine machine, long frequency = 0, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout, string simulationFilePathLinux = null, string simulationFilePathWindows = null, string simulationFilePathMacOS = null)
        {
            allTicksProcessedARE = new AutoResetEvent(initialState: false);

            verilatedPeripheral = new LibraryVerilatorConnection(this, timeout, HandleReceived);

            if(frequency != 0)
            {
                timer = new LimitTimer(machine.ClockSource, frequency, this, LimitTimerName, limitBuffer, enabled: false, eventEnabled: true, autoUpdate: true);
                timer.LimitReached += () =>
                {
                    if(!verilatedPeripheral.TrySendMessage(new ProtocolMessage(ActionType.TickClock, 0, limitBuffer)))
                    {
                        AbortAndLogError("Send error!");
                    }
                    this.NoisyLog("Tick: TickClock sent, waiting for the verilated peripheral...");
                    allTicksProcessedARE.WaitOne();
                    this.NoisyLog("Tick: Verilated peripheral finished evaluating the model.");
                };
            }

            SimulationFilePathLinux = simulationFilePathLinux;
            SimulationFilePathWindows = simulationFilePathWindows;
            SimulationFilePathMacOS = simulationFilePathMacOS;
        }

        public void Reset()
        {
            Send(ActionType.ResetPeripheral, 0, 0);
            timer.Reset();
        }

        public void Dispose()
        {
            disposeInitiated = true;
            verilatedPeripheral.Dispose();
            Marshal.FreeHGlobal(errorPointer);
        }

        public void Pause()
        {
            verilatedPeripheral.Pause();
        }

        public void Resume()
        {
            verilatedPeripheral.Resume();
        }

        public void Start()
        {
            if(SimulationFilePath == null)
            {
                throw new RecoverableException("Cannot start emulation. Set SimulationFilePath first!");
            }
            verilatedPeripheral.Start();
        }

        public bool IsPaused => verilatedPeripheral.IsPaused;

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
                if(String.IsNullOrWhiteSpace(value))
                {
                    this.Log(LogLevel.Warning, "SimulationFilePath not set!");
                    return;
                }
                else if(!String.IsNullOrWhiteSpace(SimulationFilePath))
                {
                    LogAndThrowRE("Verilated peripheral already connected, cannot change the file name!");
                }
                else if(connectedCpu.Children.Any(child => child.Peripheral.SimulationFilePath == value))
                {
                    LogAndThrowRE("Another CFU already connected to provided library!");
                }
                else
                {
                    try
                    {
                        errorPointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(int)));
                        executeBinder = new NativeBinder(this, value);
                        verilatedPeripheral.SimulationFilePath = value;
                        verilatedPeripheral.Connect();

                        if(timer != null)
                        {
                            timer.Enabled = true;
                        }
                    }
                    catch(Exception e)
                    {
                        LogAndThrowRE(e.Message);
                    }
                }
            }
        }

        public ICPU ConnectedCpu
        {
            get
            {
                return connectedCpu;
            }
            set
            {
                if(ConnectedCpu != null)
                {
                    LogAndThrowRE("CFU already connected to CPU, cannot change CPU!");
                }
                else
                {
                    connectedCpu = value as BaseRiscV;
                    if(connectedCpu == null)
                    {
                        LogAndThrowRE("CFU is supported for RISCV-V CPUs only!");
                    }
                    RegisterCFU();
                }
            }
        }

        protected void Send(ActionType actionId, ulong offset, ulong value)
        {
            if(!verilatedPeripheral.TrySendMessage(new ProtocolMessage(actionId, offset, value)))
            {
                AbortAndLogError("Send error!");
            }
        }

        protected virtual void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.InvalidAction:
                    this.Log(LogLevel.Warning, "Invalid action received");
                    break;
                case ActionType.TickClock:
                    allTicksProcessedARE.Set();
                    break;
                default:
                    this.Log(LogLevel.Warning, "Unhandled message: ActionId = {0}; Address: 0x{1:X}; Data: 0x{2:X}!",
                        message.ActionId, message.Address, message.Data);
                    break;
            }
        }

        // This function is not used here but it is required to properly bind with libVtop.so
        // so it is left empty on purpose.
        [Export]
        private void HandleSenderMessage(IntPtr received)
        {

        }

        private void AbortAndLogError(string message)
        {
            if(disposeInitiated)
            {
                return;
            }
            this.Log(LogLevel.Error, message);
            verilatedPeripheral.Abort();

            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private void LogAndThrowRE(string info)
        {
            this.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private void RegisterCFU()
        {
            string opcodePattern = "";
            int connectedCfus = connectedCpu.ChildCollection.Count;
            switch(connectedCfus)
            {
                case 1:
                    opcodePattern = "FFFFFFFAAAAABBBBBIIICCCCC0001011";
                    break;
                case 2:
                    opcodePattern = "FFFFFFFAAAAABBBBBIIICCCCC0101011";
                    break;
                case 3:
                    opcodePattern = "FFFFFFFAAAAABBBBBIIICCCCC1001011";
                    break;
                case 4:
                    opcodePattern = "FFFFFFFAAAAABBBBBIIICCCCC1101011";
                    break;
                default:
                    this.LogAndThrowRE("Can't handle more than 4 CFUs!");
                    break;
            }
            connectedCpu.InstallCustomInstruction(pattern: opcodePattern, handler: opcode => HandleCustomInstruction(opcode));
            this.Log(LogLevel.Noisy, "CFU {0} registered", connectedCfus);
        }

        private void HandleCustomInstruction(ulong opcode)
        {
            int rD = (int)BitHelper.GetValue(opcode, 7, 5);
            int rs1 = (int)BitHelper.GetValue(opcode, 15, 5);
            UInt32 rs1Value = Convert.ToUInt32(connectedCpu.GetRegister(rs1).RawValue);
            int rs2 = (int)BitHelper.GetValue(opcode, 20, 5);
            UInt32 rs2Value = Convert.ToUInt32(connectedCpu.GetRegister(rs2).RawValue);
            UInt32 funct3 = Convert.ToUInt32(BitHelper.GetValue(opcode, 12, 3));
            UInt32 funct7 = Convert.ToUInt32(BitHelper.GetValue(opcode, 25, 7));
            UInt32 functionID = (funct7 << 3) + funct3;

            UInt64 result = 0UL;
            result = execute(functionID, rs1Value, rs2Value, errorPointer);

            CfuStatus status = (CfuStatus)Marshal.ReadInt32(errorPointer);

            switch(status)
            {
                case CfuStatus.CfuOk:
                    connectedCpu.SetRegister(rD, result);
                    break;
                case CfuStatus.CfuFail:
                    this.Log(LogLevel.Error, "CFU custom instruction error, opcode: 0x{0:x}, error: {1}", opcode, status);
                    break;
                case CfuStatus.CfuTimeout:
                    this.Log(LogLevel.Error, "CFU operation timeout, opcode: 0x{0:x}, error: {1}", opcode, status);
                    break;
                default:
                    this.Log(LogLevel.Error, "CFU unknown error, opcode: 0x{0:x}, error: {1}", opcode, status);
                    break;
            }
        }

        protected const ulong LimitBuffer = 100000;
        protected const int DefaultTimeout = 3000;
        private bool disposeInitiated;
        private readonly LibraryVerilatorConnection verilatedPeripheral;
        private NativeBinder executeBinder;
        private BaseRiscV connectedCpu;
        private IntPtr errorPointer;
        private readonly AutoResetEvent allTicksProcessedARE;
        private readonly LimitTimer timer;

        private const string LimitTimerName = "CFUClock";

#pragma warning disable 649
        [Import(UseExceptionWrapper = false)]
        private FuncUInt64UInt32UInt32UInt32IntPtr execute;
#pragma warning restore 649

        private enum CfuStatus
        {
            CfuOk = 0,
            CfuFail = 1,
            CfuTimeout = 2
        }
    }
}
