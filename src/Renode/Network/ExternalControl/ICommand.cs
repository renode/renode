//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `api_command_t` in C
    public enum Command : ushort
    {
        CheckVersion = 0,
        RunFor,
        GetTime,
        GetMachine,
        ADC,
        GPIOPort,
        SystemBus,
    }

    public interface ICommand
    {
        Command Identifier { get; }

        IMachineContainer Machines { get; }

        MessagePayload Invoke(List<byte> data);
    }

    public abstract class BaseCommand : ICommand
    {
        public BaseCommand(ExternalControlServer parent)
        {
            this.parent = parent;
        }

        public abstract MessagePayload Invoke(List<byte> data);

        public IMachineContainer Machines => parent.Machines;

        public abstract Command Identifier { get; }

        protected readonly ExternalControlServer parent;
    }
}
