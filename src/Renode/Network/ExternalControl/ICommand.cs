//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
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
        TimeElapsedCallback,
        SPI,
        CANBus,
    }

    public interface ICommand
    {
        Command Identifier { get; }

        IMachineContainer Machines { get; }

        MessagePayload Invoke(MessagePayload payload);
    }

    public abstract class BaseCommand : ICommand
    {
        public BaseCommand(ExternalControlSocket parent)
        {
            this.parent = parent;
        }

        public abstract MessagePayload Invoke(MessagePayload payload);

        public IMachineContainer Machines => parent.Machines;

        public abstract Command Identifier { get; }

        protected readonly ExternalControlSocket parent;
    }
}
