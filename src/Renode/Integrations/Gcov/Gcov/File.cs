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
    public class File
    {
        public static void WriteGCNO(Writer f, IEnumerable<Function> functions, IEnumerable<string> sourcePrefixes)
        {
            var magic = new byte[]{(byte)'g',(byte)'c',(byte)'n',(byte)'o'};
            f.Write(magic);

            var version = GCC10VersionTag;
            f.Write(version);

            f.Write(Stamp);

            var currentWorkingDirectory = Directory.GetCurrentDirectory();
            f.Write(currentWorkingDirectory);

            f.Write(0); // has unexecuted block
            foreach(var function in functions)
            {
                function.WriteGcno(f, sourcePrefixes);
            }
        }

        public static void WriteGCDA(Writer f, IEnumerable<Function> functions)
        {
            var magic = new byte[]{(byte)'g',(byte)'c',(byte)'d',(byte)'a'};
            f.Write(magic);

            var version = GCC10VersionTag;
            f.Write(version);

            f.Write(Stamp);

            var summary = new Record(GcdaTagId.ObjectSummary);
            summary.Push(1); // counters
            summary.Push(0); // number
            summary.Write(f);

            foreach(var function in functions)
            {
                function.WriteGcda(f);
            }
        }

        // stamp needs to be the same for GCDA and GCNO files
        private const int Stamp = 0x1;

        private static readonly byte[] GCC10VersionTag = new byte[]{(byte)'B',(byte)'0',(byte)'2',(byte)'*'};
    }
}
