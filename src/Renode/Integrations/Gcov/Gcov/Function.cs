//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using System.Collections.Generic;

using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Integrations.Gcov
{
    public class Function : IGcdaWriter, IGcnoWriter
    {
        static private int nextId = 0;

        public Function(FunctionExecution execution, DWARF.DWARFReader dwarf)
        {
            this.execution = execution;
            identifier = nextId++;

            ProcessExecutedPCs(dwarf);
            GenerateBranchesInformation();
            ExpandGraph();
            ProcessGraph();

            artificial = execution.File == null || execution.File.Length == 0;
        }

        public void WriteGcno(Writer f, IEnumerable<string> sourcePrefixes)
        {
            if(artificial)
            {
                return;
            }

            GetGcnoFunctionHeaderRecord(sourcePrefixes).Write(f);
            GetGcnoBlocksHeaderRecord().Write(f);
            WriteGcnoBlocks(f);
            WriteGcnoLines(f, sourcePrefixes);
        }

        public void WriteGcda(Writer f)
        {
            if(artificial || blocksBranches.Count == 0)
            {
                return;
            }

            GetGcdaFunctionHeaderRecord().Write(f);
            GetGcdaCounterRecord().Write(f);
        }

        public override string ToString()
        {
            return $"{execution.File}:{execution.Name}:{startLine},{startColumn}-{endLine},{endColumn}";
        }

        private void ProcessExecutedPCs(DWARF.DWARFReader dwarf)
        {
            entryPc = ulong.MaxValue;
            startLine = int.MaxValue;
            startColumn = int.MaxValue;
            endLine = int.MinValue;
            endColumn = int.MinValue;

            foreach(var pc in execution.ExecutedPCs)
            {
                if(!dwarf.TryGetLineForPC(pc, out var line))
                {
                    Logger.Log(LogLevel.Warning, "Couldn't resolve line mapping for PC 0x{0:X}", pc);
                    continue;
                }

                pcToLine[pc] = line.LineNumber;

                if(pc < entryPc)
                {
                    entryPc = pc;
                    startLine = line.LineNumber;
                    startColumn = (int)line.Column;
                }

                if(endLine < line.LineNumber)
                {
                    endLine = line.LineNumber;
                    endColumn = (int)line.Column;
                }
            }
        }

        private bool IsOurPc(ulong pc)
        {
            return blockIndex.ContainsKey(pc);
        }

        private void GenerateBranchesInformation()
        {
            entryIndex = int.MaxValue;

            if(execution.NextPCs.Count == 0)
            {
                blocksBranches.Add(entryPc, new List<Branch>());
                return;
            }

            // index 0 is reserved for entering the function
            // index 1 is reserved for leaving the function
            // blocks start from index 2
            var index = 2;
            foreach(var pc in execution.ExecutedPCs)
            {
                blockIndex[pc] = index;
                if(pc == entryPc)
                {
                    entryIndex = index;
                }

                index += 1;
            }

            foreach(var pc in execution.ExecutedPCs)
            {
                var branches = new List<Branch>();

                var lastInstruction = !execution.NextPCs.ContainsKey(pc);
                if(lastInstruction)
                {
                    var branch = new Branch(pc, BranchFlags.Tree, 1, 0); // special block 1 TODO: const
                    branches.Add(branch);
                }
                else
                {
                    var nextPCs = execution.NextPCs[pc];
                    var possibleFallthoughBranch = nextPCs.Where(x => x > pc).DefaultIfEmpty(ulong.MaxValue).Min();
                    var singleBlock = nextPCs.Count() == 1;

                    foreach(var nextPC in nextPCs)
                    {
                        var destinationIndex = 1;
                        var flags = (nextPC == possibleFallthoughBranch)
                            ? BranchFlags.Fall
                            : BranchFlags.Tree;

                        if(!IsOurPc(nextPC))
                        {
                            // PC doesn't belong to the current function;
                            // all function calls are marked in GCOV
                            // with tree flag
                            flags = BranchFlags.Tree;
                        }
                        else
                        {
                            destinationIndex = blockIndex[nextPC];

                            if(singleBlock)
                            {
                                // this branch is guaranteed to be selected, as
                                // no conditional jump is being performed
                                flags |= BranchFlags.Fall;
                            }
                        }

                        var branch = new Branch(pc, flags, destinationIndex, nextPC);
                        branches.Add(branch);
                    }
                }

                blocksBranches.Add(pc, branches);
            }
        }

        // There are cases where we can't have branches with
        // certain flags directly after each other as that
        // would mess up the way in which GCOV handles
        // line counting, i.e., we must have after "tree+fall" branch
        // a "fall" branch
        // For those cases generate padding block that would
        // eliminate such paths.
        private KeyValuePair<ulong, List<Branch>> GeneratePaddingBlock(KeyValuePair<ulong, List<Branch>> parentBlock)
        {
            var parentBranches = new List<Branch>();
            parentBranches.Add(new Branch(parentBlock.Key + 1, BranchFlags.Fall, parentBlock.Value[0].DestinationIndex, parentBlock.Value[0].PC));

            // We identifier calculating some
            // nonsense PC that should never be used
            var uniqueIdentifier = parentBlock.Key + 1;

            return new KeyValuePair<ulong, List<Branch>>(uniqueIdentifier, parentBranches);
        }

        // Assign proper GCOV block index for new block
        private int RegisterBlock(KeyValuePair<ulong, List<Branch>> block)
        {
            // + 2 because `blockIndex` is a dictionary
            // and we don't keep there blocks #0 and #1
            var index = blockIndex.Count + 2;
            blockIndex[block.Key] = index;

            return index;
        }

        private void ExpandGraph()
        {
            var newBlocks = new Dictionary<ulong, List<Branch>>();
            foreach(var block in blocksBranches.Where(x => x.Value.Count > 0))
            {
                var isFallthroughBranch = (block.Value[0].Flags & BranchFlags.Fall) ==  BranchFlags.Fall;
                var isTreeBranch = (block.Value[0].Flags & BranchFlags.Tree) ==  BranchFlags.Tree;

                if(isFallthroughBranch && isTreeBranch)
                {
                    var paddingBlock = GeneratePaddingBlock(block);

                    newBlocks.Add(paddingBlock.Key, paddingBlock.Value);
                    block.Value[0] = new Branch(block.Key, BranchFlags.Fall | BranchFlags.Tree, RegisterBlock(paddingBlock), paddingBlock.Key);
                }
            }

            foreach(var block in newBlocks)
            {
                blocksBranches.Add(block.Key, block.Value);
            }
        }

        private void ProcessGraph()
        {
            // index 0 is reserved for entering the function
            // index 1 is reserved for leaving the function
            // blocks start from index 2
            var index = 2;
            entryIndex = index;
            foreach(var block in blocksBranches)
            {
                blockIndex[block.Key] = index;
                if(block.Key == entryPc)
                {
                    entryIndex = index;
                }

                index += 1;
            }
        }

        private Record GetGcnoFunctionHeaderRecord(IEnumerable<string> sourcePrefixes)
        {
            var functionHeader = new Record(GcnoTagId.Function);
            functionHeader.Push(identifier);
            functionHeader.Push(0x0); // line number checksum
            functionHeader.Push(0x0); // cfg checksum
            functionHeader.Push(execution.Name);
            functionHeader.Push(artificial ? (int)1 : (int)0);
            functionHeader.Push(FilterPath(execution.File, sourcePrefixes));

            functionHeader.Push(startLine);
            functionHeader.Push(startColumn);
            functionHeader.Push(endLine);
            functionHeader.Push(endColumn);

            return functionHeader;
        }

        private Record GetGcnoBlocksHeaderRecord()
        {
            var blockHeader = new Record(GcnoTagId.Block);

            var numberOfBlocks = blocksBranches.Count + 1;
            var numberOfLines = blocksBranches.Where(pk => pcToLine.ContainsKey(pk.Key)).Count();

            blockHeader.Push(numberOfBlocks + numberOfLines);
            return blockHeader;
        }

        private void WriteGcnoBlocks(Writer writer)
        {
            // Writing the entry point block
            GetArcRecord(0, new List<Branch> { new Branch(0, BranchFlags.Fall, entryIndex, 0) }).Write(writer);

            var index = 2;
            foreach(var block in blocksBranches)
            {
                GetArcRecord(index, block.Value).Write(writer);
                index += 1;
            }
        }

        private Record GetArcRecord(int index, List<Branch> branches)
        {
            var arc = new Record(GcnoTagId.Arc);
            arc.Push(index);
            foreach(var b in branches)
            {
                b.FillRecord(arc);
            }
            return arc;
        }

        private void WriteGcnoLines(Writer writer, IEnumerable<string> sourcePrefixes)
        {
            foreach(var branch in blocksBranches.Where(x => pcToLine.ContainsKey(x.Key)))
            {
                var pc = branch.Key;
                GetLineRecord(pc, sourcePrefixes).Write(writer);
            }
        }

        private Record GetLineRecord(ulong pc, IEnumerable<string> sourcePrefixes)
        {
            var record = new Record(GcnoTagId.Line);

            record.Push(blockIndex[pc]); //index

            record.Push(0); // line number, 0 is followed by the filename
            record.Push(FilterPath(execution.File, sourcePrefixes));

            record.Push(pcToLine[pc]); // line number

            record.Push(0); // line number
            record.Push(0); // null filename - concludes a list

            return record;
        }

        private string FilterPath(string path, IEnumerable<string> sourcePrefixes)
        {
            foreach(var sourcePrefix in sourcePrefixes.Where(x => path.StartsWith(x)))
            {
                var res = path.Substring(sourcePrefix.Length);
                return res;
            }
            return path;
        }

        private Record GetGcdaFunctionHeaderRecord()
        {
            var functionHeader = new Record(GcdaTagId.Function);

            functionHeader.Push(identifier);
            functionHeader.Push(0); // line no checksum, must be the same as in GCNO
            functionHeader.Push(0); // cfg checksum, must be the same as in GCNO

            return functionHeader;
        }

        private Record GetGcdaCounterRecord()
        {
            var writtenBlocks = new HashSet<int>();

            var countableBlockPc = blocksBranches
                .Where(pk => pk.Value.Any(branch => (branch.Flags & (BranchFlags.Fall | BranchFlags.Tree)) == BranchFlags.Fall))
                .Select(pk => pk.Value.First(branch => (branch.Flags & BranchFlags.Fall) == BranchFlags.Fall).DestinationIndex)
                .Where(index => index != 1);

            var record = new Record(GcdaTagId.Counts);
            record.Push(execution.GetCallsCount(entryPc));
            foreach(var index in countableBlockPc)
            {
                var count = (writtenBlocks.Contains(index))
                    ? (ulong)0
                    : execution.GetCallsCount(blockIndex.First(block => block.Value == index).Key);

                record.Push(count);
                writtenBlocks.Add(index);
            }

            return record;
        }

        private int entryIndex;
        private ulong entryPc;
        private int startLine;
        private int startColumn;
        private int endLine;
        private int endColumn;

        private readonly FunctionExecution execution;
        private readonly int identifier;
        private readonly bool artificial;

        // maps PC to branches
        private readonly Dictionary<ulong, List<Branch>> blocksBranches = new Dictionary<ulong, List<Branch>>();
        // maps PC to block index
        private readonly Dictionary<ulong, int> blockIndex = new Dictionary<ulong, int>();
        // maps PC to line number
        private readonly Dictionary<ulong, int> pcToLine = new Dictionary<ulong, int>();
    }
}
