//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.Memory
{
    // A simple byte-addressable memory peripheral that does NOT implement IMapped.
    // This simulates dynamically compiled C# peripherals that act as executable memory
    // but go through I/O callbacks for all accesses.
    public class ExecutableByteMemory : IBytePeripheral, IWordPeripheral, IDoubleWordPeripheral, IKnownSize
    {
        public ExecutableByteMemory(int size)
        {
            this.size = size;
            data = new byte[size];
        }

        public byte ReadByte(long offset)
        {
            return data[offset];
        }

        public void WriteByte(long offset, byte value)
        {
            data[offset] = value;
        }

        public ushort ReadWord(long offset)
        {
            return (ushort)(data[offset] | (data[offset + 1] << 8));
        }

        public void WriteWord(long offset, ushort value)
        {
            data[offset] = (byte)value;
            data[offset + 1] = (byte)(value >> 8);
        }

        public uint ReadDoubleWord(long offset)
        {
            return (uint)(data[offset] | (data[offset + 1] << 8) |
                          (data[offset + 2] << 16) | (data[offset + 3] << 24));
        }

        public void WriteDoubleWord(long offset, uint value)
        {
            data[offset] = (byte)value;
            data[offset + 1] = (byte)(value >> 8);
            data[offset + 2] = (byte)(value >> 16);
            data[offset + 3] = (byte)(value >> 24);
        }

        public void Reset()
        {
            for(int i = 0; i < data.Length; i++)
            {
                data[i] = 0;
            }
        }

        public long Size { get { return size; } }

        private readonly int size;
        private readonly byte[] data;
    }
}
