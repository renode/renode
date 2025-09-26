//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.PlatformDescription
{
    public class ConversionResult
    {
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

        public ConversionResult(ConversionResultType resultType, ParsingError error, string message)
        {
            ResultType = resultType;
            Error = error;
            Message = message;
        }

        public ConversionResultType ResultType { get; private set; }

        public ParsingError Error { get; private set; }

        public string Message { get; private set; }
    }
}