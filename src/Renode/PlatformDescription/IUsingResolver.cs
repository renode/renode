//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.PlatformDescription
{
    public interface IUsingResolver
    {
        string Resolve(string argument, string includingFile);
    }
}