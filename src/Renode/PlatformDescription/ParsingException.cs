//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Exceptions;

namespace Antmicro.Renode.PlatformDescription
{
    public class ParsingException : RecoverableException
    {
        public ParsingException(ParsingError error, string message) : base(message)
        {
            Error = error;
        }

        public ParsingError Error { get; private set; }
    }
}