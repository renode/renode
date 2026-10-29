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

        var getMachineHandler = new GetMachine(this);
        Machines = getMachineHandler;

        commandHandlers = new ICommand[]
        {
            new TimeElapsedCallbackCommand(this),
            new RunFor(this),
            new GetTime(this),
            new SPI(this),
            new ADC(this),
            new GPIOPort(this),
            new SystemBus(this),
            new CheckVersion(this),
            new CANBus(this),
            new CustomCommand(this),
            getMachineHandler,
        }.ToDictionary(handler => handler.Identifier);
    }

    public ICommand? GetCommandHandler(Command command)
    {
        if(!commandHandlers.TryGetValue(command, out var handler))
        {
            return null;
        }
        return handler;
    }

    public void Dispose()
    {
        foreach(var handler in commandHandlers.Values.OfType<IDisposable>())
        {
            handler.Dispose();
        }
        commandHandlers.Clear();
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

    private readonly Dictionary<Command, ICommand> commandHandlers;
    private readonly Func<MessagePayload, MessagePayload> sendRequest;
}
