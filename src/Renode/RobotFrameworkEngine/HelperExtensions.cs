//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using System.Text;

namespace Antmicro.Renode.RobotFramework
{
    public static class HelperExtensions
    {
        public static string StripNonSafeCharacters(this string input)
        {
            return Encoding.UTF8.GetString(Encoding.UTF8.GetBytes(input).Where(x => (x >= 32 && x <= 126) || (x == '\n')).ToArray());
        }
    }
}