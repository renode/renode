//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.UserInterface;

using AntShell.Commands;

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
        CustomCommand,
        Emulation,
    }

    public interface ICommand
    {
        Command Identifier { get; }

        IMachineContainer Machines { get; }

        MessagePayload Invoke(MessagePayload payload);
    }

    public abstract class BaseCommand : ICommand
    {
        public BaseCommand(ExternalControlEndpoint parent)
        {
            this.parent = parent;
        }

        public abstract MessagePayload Invoke(MessagePayload payload);

        public IMachineContainer Machines => parent.Machines;

        public abstract Command Identifier { get; }

        // Runs `interact` with the Monitor and with an interaction that collects what the Monitor writes. The response
        // is an error with what the Monitor wrote as errors, or a success with the rest of what it wrote.
        protected MessagePayload InteractWithMonitor(Func<Monitor, ICommandInteraction, bool> interact)
        {
            lock(monitorInteractionLock)
            {
                var monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
                var interaction = WrapMonitorInteraction(monitor);
                interaction.Clear();

                var succeeded = interact(monitor, interaction);
                var error = interaction.GetError();
                if(!succeeded || error.Length > 0)
                {
                    return MessagePayload.Error(Identifier, error.Trim());
                }
                return MessagePayload.Success(Identifier, interaction.GetContents());
            }
        }

        protected readonly ExternalControlEndpoint parent;

        // The wrapper also collects what the Monitor writes to its own interaction, such as the error of a line in a
        // script.
        private static CommandInteractionWrapper WrapMonitorInteraction(Monitor monitor)
        {
            if(monitor.Interaction is not CommandInteractionWrapper wrapper)
            {
                wrapper = new CommandInteractionWrapper(monitor.Interaction);
                monitor.Interaction = wrapper;
            }
            return wrapper;
        }

        // Requests share the Monitor and the wrapper of its interaction, so a request holds this lock from clearing the
        // wrapper until it has read its output from the wrapper.
        private static readonly object monitorInteractionLock = new object();
    }
}
