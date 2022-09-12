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
    public interface IGcnoWriter
    {
        ///
        /// <summary>
        /// Writes object into .gcno file
        /// </summary>
        ///
        void WriteGcno(Writer writer, IEnumerable<string> sourcePrefixes);
    }
}
