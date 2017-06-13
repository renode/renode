//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
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
