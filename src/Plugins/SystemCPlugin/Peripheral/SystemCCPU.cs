//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Time;

using ELFSharp.ELF;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public abstract class SystemCCPU : BaseCPU, IGPIOReceiver, ITimeSink, IDisposable
    {
        public SystemCCPU(IMachine machine, string address, int port, string cpuType, Endianess endianess = Endianess.LittleEndian, CpuBitness bitness = CpuBitness.Bits32, int timeSyncPeriodUS = 1000, bool disableTimeoutCheck = false)
            : base(0, cpuType, machine, endianess, bitness)
        {
            systemCPeripheral = new SystemCPeripheral(machine, address, port, timeSyncPeriodUS, disableTimeoutCheck);
        }

        public virtual void SetRegisterValue32(int register, uint value)
        {
            systemCPeripheral.WriteRegister(4, (long)register, value);
        }

        public virtual uint GetRegisterValue32(int register)
        {
            return (uint)systemCPeripheral.ReadRegister(4, (long)register);
        }

        public override void Dispose()
        {
            systemCPeripheral.Dispose();
        }

        public override ExecutionResult ExecuteInstructions(ulong numberOfInstructionsToExecute, out ulong numberOfExecutedInstructions)
        {
            numberOfExecutedInstructions = numberOfInstructionsToExecute;
            totalExecutedInstructions += numberOfInstructionsToExecute;
            return ExecutionResult.Ok;
        }

        public void OnGPIO(int number, bool value)
        {
            systemCPeripheral.OnGPIO(number, value);
        }

        public void AddDirectConnection(byte connectionIndex, IDirectAccessPeripheral target)
        {
            systemCPeripheral.AddDirectConnection(connectionIndex, target);
        }

        public ulong ReadQuadWord(long offset)
        {
            return systemCPeripheral.ReadQuadWord(offset);
        }

        public void WriteQuadWord(long offset, ulong value)
        {
            systemCPeripheral.WriteQuadWord(offset, value);
        }

        public uint ReadDoubleWord(long offset)
        {
            return systemCPeripheral.ReadDoubleWord(offset);
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            systemCPeripheral.WriteDoubleWord(offset, value);
        }

        public ushort ReadWord(long offset)
        {
            return systemCPeripheral.ReadWord(offset);
        }

        public void WriteWord(long offset, ushort value)
        {
            systemCPeripheral.WriteWord(offset, value);
        }

        public byte ReadByte(long offset)
        {
            return systemCPeripheral.ReadByte(offset);
        }

        public void WriteByte(long offset, byte value)
        {
            systemCPeripheral.WriteByte(offset, value);
        }

        public ulong ReadDirect(byte dataLength, long offset, byte connectionIndex)
        {
            return systemCPeripheral.ReadDirect(dataLength, offset, connectionIndex);
        }

        public void WriteDirect(byte dataLength, long offset, ulong value, byte connectionIndex)
        {
            systemCPeripheral.WriteDirect(dataLength, offset, value, connectionIndex);
        }

        public override void Reset()
        {
            totalExecutedInstructions = 0;
            systemCPeripheral.Reset();
            base.Reset();
        }

        public override ulong ExecutedInstructions => totalExecutedInstructions;

        public string SystemCExecutablePath
        {
            get => systemCPeripheral.SystemCExecutablePath;
            set => systemCPeripheral.SystemCExecutablePath = value;
        }

        private ulong totalExecutedInstructions;

        private readonly SystemCPeripheral systemCPeripheral;
    }
}