//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Network.ExternalControl;

#nullable enable

namespace Antmicro.Renode.Network;

/// <summary>
/// One end of an external control connection. It runs the commands that the other end requests and sends requests to
/// the other end. The transport that carries the connection's messages owns it.
/// </summary>
public sealed class ExternalControlEndpoint : IDisposable
{
    public ExternalControlEndpoint(IEmulationElement owner, Func<MessagePayload, MessagePayload> sendRequest)
    {
        Owner = owner;
        this.sendRequest = sendRequest;

        commandHandlers = new CommandHandlerCollection();
        commandHandlers.Register(new TimeElapsedCallbackCommand(this));
        commandHandlers.Register(new RunFor(this));
        commandHandlers.Register(new GetTime(this));
        commandHandlers.Register(new SPI(this));
        commandHandlers.Register(new ADC(this));
        commandHandlers.Register(new GPIOPort(this));
        commandHandlers.Register(new SystemBus(this));
        commandHandlers.Register(new CheckVersion(this));
        commandHandlers.Register(new CANBus(this));
        commandHandlers.Register(new CustomCommand(this));

        var getMachineHandler = new GetMachine(this);
        Machines = getMachineHandler;

        commandHandlers.Register(getMachineHandler);
    }

    public ICommand? GetCommandHandler(Command command)
    {
        return commandHandlers.GetHandler(command);
    }

    public void Dispose()
    {
        commandHandlers.Dispose();
    }

    /// <summary>
    /// Sends a request to the other end and returns its response.
    /// </summary>
    public MessagePayload SendRequest(MessagePayload request)
    {
        return sendRequest(request);
    }

    /// <summary>
    /// The transport that owns this endpoint. Commands log through it, so that their messages carry its name.
    /// </summary>
    public IEmulationElement Owner { get; }

    public IMachineContainer Machines { get; }

    private readonly CommandHandlerCollection commandHandlers;
    private readonly Func<MessagePayload, MessagePayload> sendRequest;

    private class CommandHandlerCollection : IDisposable
    {
        public CommandHandlerCollection()
        {
            commandHandlers = new Dictionary<Command, ICommand>();
        }

        public void Dispose()
        {
            foreach(var command in commandHandlers.Values.OfType<IDisposable>())
            {
                command.Dispose();
            }
            commandHandlers.Clear();
        }

        public void Register(ICommand command)
        {
            commandHandlers.Add(command.Identifier, command);
        }

        public ICommand? GetHandler(Command id)
        {
            if(!commandHandlers.TryGetValue(id, out var command))
            {
                return null;
            }
            return command;
        }

        private readonly Dictionary<Command, ICommand> commandHandlers;
    }
}
