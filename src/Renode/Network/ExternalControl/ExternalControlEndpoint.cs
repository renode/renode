//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Network.ExternalControl;

#nullable enable

namespace Antmicro.Renode.Network;

/// <summary>
/// One end of an external control connection. The transport that carries the connection's messages owns it.
/// </summary>
public sealed class ExternalControlEndpoint
{
    public ExternalControlEndpoint(IEmulationElement owner, Func<MessagePayload, MessagePayload> sendRequest)
    {
        Owner = owner;
        this.sendRequest = sendRequest;
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

    public IMachineContainer? Machines { get; set; }

    private readonly Func<MessagePayload, MessagePayload> sendRequest;
}
