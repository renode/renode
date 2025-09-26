//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.PlatformDescription.Syntax;

namespace Antmicro.Renode.PlatformDescription
{
    public sealed class Variable
    {
        public Variable(Type variableType, DeclarationPlace declarationPlace)
        {
            associatedEntries = new List<Entry>();
            VariableType = variableType;
            DeclarationPlace = declarationPlace;
        }

        public void AddEntry(Entry entry)
        {
            associatedEntries.Add(entry);
        }

        public Entry GetMergedEntry()
        {
            if(associatedEntries.Count == 0)
            {
                return null;
            }
            var entriesToMerge = associatedEntries.ToList();
            Entry result = entriesToMerge[0];
            result = entriesToMerge.Skip(1).Aggregate(entriesToMerge[0], (x, y) => x.MergeWith(y));
            result.Variable = this;
            return result;
        }

        public Type VariableType { get; set; }

        public DeclarationPlace DeclarationPlace { get; set; }

        public object Value { get; set; }

        private readonly List<Entry> associatedEntries;
    }
}