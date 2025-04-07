//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.PlatformDescription.Syntax
{
    //Empty Value means default(T) property or constructor value in platform description file
    public class EmptyValue : Value
    {
        public static EmptyValue Instance { get; } = new EmptyValue();
    }
}