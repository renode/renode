//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;
using System.Text;

using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals.SystemC
{
    // WARNING: This structure is part of a binary socket protocol between C and C#.
    // Any change MUST be mirrored in struct dmi_message in renode_bridge.h
    // or communication will not work correctly.
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct FileMappingParameters
    {
        public FileMappingParameters(ulong startAddress, ulong endAddress, ulong mmfOffset, string mmfPath, IntPtr mappedAddress)
        {
            StartAddress = startAddress;
            EndAddress = endAddress;
            MMFOffset = mmfOffset;
            MMFPath = new byte[PathMax];
            var mmfPathBytes = Encoding.UTF8.GetBytes(mmfPath);
            if(mmfPathBytes.Length > PathMax)
            {
                Logger.Log(LogLevel.Error, "MMF path name is too long");
            }
            Array.Copy(mmfPathBytes, MMFPath, mmfPathBytes.Length);
            MMFPathByteCount = (uint)mmfPathBytes.Length;
            MappedAddress = mappedAddress;
        }

        public readonly ulong StartAddress;
        public readonly ulong EndAddress;
        public readonly ulong MMFOffset;
        public readonly uint MMFPathByteCount;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = PathMax)]
        public readonly byte[] MMFPath;
        public readonly IntPtr MappedAddress;

        public const int PathMax = 4096;
    }
}
