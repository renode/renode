//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.IO;

namespace Antmicro.Renode.Integrations.Gcov
{
    public class Record
    {
        public Record(GcnoTagId tag)
        {
            this.tag = (int)tag;
            data = new List<Element>();
        }

        public Record(GcdaTagId tag)
        {
            this.tag = (int)tag;
            data = new List<Element>();
        }

        public void Write(Writer f)
        {
            var count = 0;
            foreach(var d in data)
            {
                if(d.String != null)
                {
                    // strings are preceeded with the length
                    count += Writer.SizeOf(d.String) + 1;
                }
                else if(d.Value32.HasValue)
                {
                    count++;
                }
                else // 64-bit value
                {
                    count += 2;
                }
            }

            f.Write(tag);
            f.Write(count);

            foreach(var d in data)
            {
                if(d.String != null)
                {
                    f.Write(d.String);
                }
                else if(d.Value32.HasValue)
                {
                    f.Write(d.Value32.Value);
                }
                else
                {
                    f.Write(d.Value64.Value);
                }
            }
        }

        public void Push(int e)
        {
            data.Add(new Element { Value32 = e });
        }

        public void Push(ulong e)
        {
            data.Add(new Element { Value64 = e });
        }

        public void Push(string s)
        {
            data.Add(new Element { String = s });
        }

        private readonly List<Element> data;
        private readonly int tag;

        private struct Element
        {
            public string String;
            public int? Value32;
            public ulong? Value64;
        }
    }
}
