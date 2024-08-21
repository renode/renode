//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

namespace Antmicro.Renode.Network.ExternalControl
{
    public enum Command : byte
    {
        RunFor = 1,
        GetTime,
        GetMachine,
        ADC,
        GPIOPort,
    }

    public interface ICommand
    {
        Command Identifier { get; }
        byte Version { get; }
        IMachineContainer Machines { get; }

        Response Invoke(List<byte> data);
    }

    public abstract class BaseCommand : ICommand
    {
        public BaseCommand(ExternalControlServer parent)
        {
            this.parent = parent;
        }

        public abstract Response Invoke(List<byte> data);

        public abstract Command Identifier { get; }
        public abstract byte Version { get; }
        public IMachineContainer Machines => parent.Machines;

        protected readonly ExternalControlServer parent;
    }

    public interface IHasEvents : ICommand
    {
        event Action<Response> EventReported;
    }
}
