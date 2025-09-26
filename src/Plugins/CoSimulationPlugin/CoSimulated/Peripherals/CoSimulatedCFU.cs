//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.CFU;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Binding;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class CoSimulatedCFU : ICFU, ICoSimulationConnectible, IDisposable
    {
        public CoSimulatedCFU(Machine machine, long frequency = 0, ulong limitBuffer = LimitBuffer, int timeout = DefaultTimeout)
        {
            // Multiple CoSimulatedCFUs per CoSimulationConnection are currently not supported.
            RenodeToCosimIndex = 0;
            CosimToRenodeIndex = 0;

            connection = new CoSimulationConnection(machine, "cosimulation_connection", frequency, limitBuffer, timeout, null, 0, 0);
            connection.AttachTo(this);
            errorPointer = IntPtr.Zero;
        }

        public virtual void OnConnectionAttached(CoSimulationConnection connection)
        {
        }

        public virtual void OnConnectionDetached(CoSimulationConnection connection)
        {
        }

        public void Reset()
        {
            connection?.Reset();
        }

        public void Dispose()
        {
            connection.Dispose();
            executeBinder?.Dispose();
            Marshal.FreeHGlobal(errorPointer);
        }

        public string SimulationFilePath
        {
            get => connection.SimulationFilePath;
            set
            {
                AssureIsConnected();
                AssureNoConflictingCFUs(value);
                connection.SimulationFilePath = value;
                InitNativeBinding(value);
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

        public int RenodeToCosimIndex { get; }

        public int CosimToRenodeIndex { get; }

        public string SimulationContextLinux
        {
            get => connection.SimulationContextLinux;
            set
            {
                AssureIsConnected();
                connection.SimulationContextLinux = value;
            }
        }

        public string SimulationContextWindows
        {
            get => connection.SimulationContextWindows;
            set
            {
                AssureIsConnected();
                connection.SimulationContextWindows = value;
            }
        }

        public string SimulationContextMacOS
        {
            get => connection.SimulationContextMacOS;
            set
            {
                AssureIsConnected();
                connection.SimulationContextMacOS = value;
            }
        }

        public string SimulationContext
        {
            get => connection.SimulationContext;
            set
            {
                AssureIsConnected();
                connection.SimulationContext = value;
            }
        }

        public string SimulationFilePathLinux
        {
            get => connection.SimulationFilePathLinux;
            set
            {
#if PLATFORM_LINUX
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathWindows
        {
            get => connection.SimulationFilePathWindows;
            set
            {
#if PLATFORM_WINDOWS
                SimulationFilePath = value;
#endif
            }
        }

        public string SimulationFilePathMacOS
        {
            get => connection.SimulationFilePathMacOS;
            set
            {
#if PLATFORM_OSX
                SimulationFilePath = value;
#endif
            }
        }

        protected CoSimulationConnection connection;

        protected const ulong LimitBuffer = 100000;
        protected const int DefaultTimeout = 3000;

        private void AssureNoConflictingCFUs(string simulationFilePath)
        {
            if(connectedCpu.Children.Any(child => child.Peripheral.SimulationFilePath == simulationFilePath))
            {
                LogAndThrowRE("Another CFU already connected to provided library!");
            }
        }

        private void InitNativeBinding(string simulationFilePath)
        {
            try
            {
                errorPointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(int)));
                executeBinder = new NativeBinder(this, simulationFilePath);
            }
            catch(Exception e)
            {
                LogAndThrowRE(e.Message);
            }
        }

        // This function is not used here but it is required to properly bind with libVtop.so
        // so it is left empty on purpose.
        [Export]
        private void HandleSenderMessage(IntPtr _)
        {
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

        private void AssureIsConnected()
        {
            if(connection == null)
            {
                throw new RecoverableException("CoSimulatedPeripheral is not attached to a CoSimulationConnection.");
            }
        }

        private NativeBinder executeBinder;
        private BaseRiscV connectedCpu;
        private IntPtr errorPointer;

#pragma warning disable 649
        [Import(UseExceptionWrapper = false)]
        private readonly Func<uint, uint, uint, IntPtr, ulong> execute;
#pragma warning restore 649

        private enum CfuStatus
        {
            CfuOk = 0,
            CfuFail = 1,
            CfuTimeout = 2
        }
    }
}