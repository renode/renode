//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class Description : IVisitable
    {
        public Description(IEnumerable<UsingEntry> usings, IEnumerable<Entry> entries)
        {
            Usings = usings;
            Entries = entries;
        }

        public IEnumerable<object> Visit()
        {
            return (Usings ?? Enumerable.Empty<UsingEntry>()).Cast<object>().Concat(Entries ?? Enumerable.Empty<Entry>());
        }

        public IEnumerable<UsingEntry> Usings { get; private set; }

        public IEnumerable<Entry> Entries { get; private set; }

        public string Source { get; set; }

        public string FileName { get; set; }
    }
}