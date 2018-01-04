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
using Sprache;

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
            Entry result;
            if(associatedEntries.Count == 1)
            {
                result = associatedEntries[0];
            }
            else
            {
                var firstEntry = associatedEntries[0];
                // shallow copy is good enough here, we just don't want to change the original entry
                var firstEntryCopy = firstEntry.MakeShallowCopy();
                result = associatedEntries.Skip(1).Aggregate(firstEntryCopy, (x, y) => x.MergeWith(y));
            }
            result.Variable = this;
            return result;
        }

        public Type VariableType { get; set; }
        public DeclarationPlace DeclarationPlace { get; set; }
        public object Value { get; set; }

        private readonly List<Entry> associatedEntries;
    }

}
