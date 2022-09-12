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
    public interface IGcdaWriter
    {
        ///
        /// <summary>
        /// Writes object into .gcda file
        /// </summary>
        ///
        void WriteGcda(Writer writer);
    }
}
