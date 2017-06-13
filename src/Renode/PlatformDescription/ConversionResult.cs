//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;

namespace Antmicro.Renode.PlatformDescription
{
    public class ConversionResult
    {
        public ConversionResult(ConversionResultType resultType, ParsingError error, string message)
        {
            ResultType = resultType;
            Error = error;
            Message = message;
        }

        public static ConversionResult Success
        {
            get
            {
                return new ConversionResult(ConversionResultType.ConversionSuccessful, default(ParsingError), default(string));
            }
        }

        public static ConversionResult ConversionNotApplied
        {
            get
            {
                return new ConversionResult(ConversionResultType.ConversionNotApplied, default(ParsingError), default(string));
            }
        }

        public ConversionResultType ResultType { get; private set; }
        public ParsingError Error { get; private set; }
        public string Message { get; private set; }
    }
}
