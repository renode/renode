//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

namespace Antmicro.Renode.Network.ExternalControl
{
    public enum Command : byte
    {
        RunFor = 1,
    }

    public interface ICommand
    {
        Command Identifier { get; }
        byte Version { get; }

        Response Invoke(List<byte> data);
    }

    public abstract class BaseCommand : ICommand
    {
        public BaseCommand(IEmulationElement parent)
        {
            this.parent = parent;
        }

        public abstract Response Invoke(List<byte> data);

        public abstract Command Identifier { get; }
        public abstract byte Version { get; }

        protected readonly IEmulationElement parent;
    }
}
