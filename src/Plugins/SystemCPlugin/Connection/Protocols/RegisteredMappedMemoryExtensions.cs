//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Memory;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public static class RegisteredMappedMemoryExtensions
    {
        public static FileMappingParameters? GetFileMappingParameters(this IBusRegistered<MappedMemory> memory, ulong address)
        {
            if(!memory.Peripheral.UsingSharedMemory)
            {
                return null;
            }
            var memBase = (long)(memory.RegistrationPoint.Range.StartAddress + memory.RegistrationPoint.Offset);
            var memOffset = (long)address - memBase;
            var segmentStart = (ulong)memBase + (ulong)(memOffset - (memOffset % memory.Peripheral.SegmentSize));
            var segmentNo = (int)(memOffset / memory.Peripheral.SegmentSize);
            if(segmentNo < 0 || segmentNo >= memory.Peripheral.SegmentCount)
            {
                return null;
            }
            return new FileMappingParameters(
                segmentStart,
                segmentStart + (ulong)memory.Peripheral.SegmentSize - 1UL, // segment end
                memory.Peripheral.GetSegmentAlignmentOffset(segmentNo), // offset into the MMF corresponding to the segment start address
                memory.Peripheral.GetSegmentPath(segmentNo), // MMF path
                memory.Peripheral.GetSegmentMappedAddress(segmentNo) // mmap base address
            );
        }
    }
}
