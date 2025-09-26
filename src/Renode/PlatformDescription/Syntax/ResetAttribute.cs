//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class ResetAttribute : Attribute
    {
        public ResetAttribute(IEnumerable<string> lines, bool isAdd)
        {
            Lines = lines.ToArray();
            IsAdd = isAdd;
        }

        public ResetAttribute Merge(ResetAttribute other)
        {
            if(other.IsAdd)
            {
                // the result is a modified reset attribute, which has the same position information as the original reset attribute
                // this can be a problem if validation depends on specific statements of reset, not on the existence of reset per se
                // in such case an reset statement should be changed to be a separate grammar unit which is .Positioned
                Lines = Lines.Concat(other.Lines);
                return this;
            }
            return other;
        }

        public bool IsAdd { get; private set; }

        public IEnumerable<string> Lines { get; private set; }
    }

    // the class is there because we are not able to have position aware IEnumerable
}