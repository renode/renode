//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.Integrations.Gcov
{
    public class FunctionExecution
    {
        public FunctionExecution(string name, string file)
        {
            Name = name;
            File = file;

            executedPCs = new Dictionary<ulong, ulong>();
            nextPCs = new Dictionary<ulong, IEnumerable<ulong>>();
        }

        public void MergeWith(FunctionExecution otherExecution)
        {
            foreach(var executedPC in otherExecution.executedPCs)
            {
                if(!this.executedPCs.ContainsKey(executedPC.Key))
                {
                    this.executedPCs[executedPC.Key] = executedPC.Value;
                }
                else
                {
                    this.executedPCs[executedPC.Key] += executedPC.Value;
                }
            }

            foreach(var nextPC in otherExecution.nextPCs)
            {
                if(!this.nextPCs.ContainsKey(nextPC.Key))
                {
                    this.nextPCs[nextPC.Key] = new HashSet<ulong>();
                }

                foreach(var pc in nextPC.Value)
                {
                    ((HashSet<ulong>)this.nextPCs[nextPC.Key]).Add(pc);
                }
            }
        }

        public ulong GetCallsCount(ulong pc)
        {
            if(!executedPCs.TryGetValue(pc, out var result))
            {
                result = 0;
            }
            return result;
        }

        public IEnumerable<ulong> GetNextPCs(ulong pc)
        {
            if(!nextPCs.TryGetValue(pc, out var result))
            {
                return Enumerable.Empty<ulong>();
            }
            return result;
        }

        public void PushBlock(ulong pc)
        {
            if(!executedPCs.ContainsKey(pc))
            {
                executedPCs[pc] = 1;
            }
            else
            {
                executedPCs[pc] += 1;
            }

            if(prevPC.HasValue)
            {
                if(!nextPCs.TryGetValue(prevPC.Value, out var jumps))
                {
                    jumps = new HashSet<ulong>();
                    nextPCs[prevPC.Value] = jumps;
                }
                ((HashSet<ulong>)jumps).Add(pc);
            }

            prevPC = pc;
        }

        public override string ToString()
        {
            return $"[FunExec {Name}@{File}::\n  "
                + string.Join("\n  ", ExecutedPCs.Select(x => x.ToString("x") + " #" + executedPCs[x].ToString() + " times"))
                + "]";
        }

        public IEnumerable<ulong> ExecutedPCs => executedPCs.Keys.OrderBy(x => x);
        public Dictionary<ulong, IEnumerable<ulong>> NextPCs => nextPCs.ToDictionary(kv => kv.Key, kv => kv.Value.OrderBy(x => x).AsEnumerable());

        public string Name { get; }
        public string File { get; }

        private ulong? prevPC;

        // executed PC to count mapping
        private readonly Dictionary<ulong, ulong> executedPCs;
        private readonly Dictionary<ulong, IEnumerable<ulong>> nextPCs;
    }
}
