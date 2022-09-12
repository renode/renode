//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

namespace Antmicro.Renode.Integrations.Gcov
{
    public struct Branch
    {
        public Branch(ulong pc, BranchFlags flags, int destinationIndex, ulong destPC)
        {
            PC = pc;
            this.destPC = destPC;
            Flags = flags;
            DestinationIndex = destinationIndex;
        }

        public void FillRecord(Record r)
        {
            r.Push(DestinationIndex);
            r.Push((int)Flags);
        }

        public override string ToString()
        {
            return $"[BlockBranch: 0x{PC:X}:: {Flags}, {DestinationIndex} -> 0x{destPC:X}]";
        }

        public int DestinationIndex { get; }
        public BranchFlags Flags { get; }

        public ulong PC { get; }
        private ulong destPC;
    }
}
