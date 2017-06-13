//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Emul8.Exceptions;

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
