//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Text;

using Antmicro.Renode.Logging;

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

        protected void LogOnErrorResponse(MessagePayload payload)
        {
            switch(payload.Type)
            {
            case CommandType.Success:
                // Do nothing on success
                break;
            case CommandType.Error:
                try
                {
                    parent.ErrorLog("Command {0} failed with: {1}", Identifier, Encoding.UTF8.GetString(payload.Data));
                }
                catch(ArgumentException e)
                {
                    parent.ErrorLog("Cannot decode an error response for command {0} due to: {1} (raw data: {2})", Identifier, e.Message, payload);
                }
                break;
            case CommandType.InvalidCommand:
                parent.ErrorLog("Command {0} is not supported by the connected external", Identifier);
                break;
            default:
                parent.ErrorLog("Unexpected response type: {0} for command {1}", payload.Type, Identifier);
                break;
            }
        }

        protected readonly ExternalControlServer parent;
    }
}
