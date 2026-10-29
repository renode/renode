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

#nullable enable

namespace Antmicro.Renode.Network.ExternalControl;

public class RequestStack
{
    public RequestStack(IEmulationElement owner)
    {
        this.owner = owner;
    }

    public void Push(MessageDirection direction, Message request)
    {
        requestStack.Push((direction, request));
    }

    public void Pop(MessageDirection direction, Message response)
    {
        var errorMessages = new List<string>();

        if(requestStack.Count == 0)
        {
            errorMessages.Add("Unexpected message received");
        }
        else
        {
            var (requestDirection, request) = requestStack.Peek();

            if(response.Payload.Type.IsRequest())
            {
                errorMessages.Add("Unexpected request when a response is expected");
            }

            if(request.Id != response.Id)
            {
                errorMessages.Add("Different request and response IDs");
            }

            if(request.Payload.Command != response.Payload.Command)
            {
                errorMessages.Add("Different request and response commands");
            }

            if(direction == requestDirection)
            {
                errorMessages.Add("Unexpected message");
            }
        }

        if(errorMessages.Count > 0)
        {
            owner.Log(LogLevel.Error, "{0}\nCurrently handling:\n{1} {2}\nError: {3}", this, DirectionToString(direction), response, String.Join(", ", errorMessages));
        }

        requestStack.TryPop(out _);
    }

    public override string ToString()
    {
        var sb = new StringBuilder();

        sb.Append("Request stack (<- means received):\n");

        var depth = 0;
        foreach(var (direction, message) in requestStack)
        {
            if(depth != 0)
            {
                sb.Append('\n');
            }

            sb.AppendFormat("{0} {1}", DirectionToString(direction), message.ToCustomString(withData: false));
            depth++;
        }

        return sb.ToString();
    }

    private static string DirectionToString(MessageDirection direction)
    {
        return direction == MessageDirection.Sent ? "->" : "<-";
    }

    private readonly IEmulationElement owner;
    private readonly Stack<(MessageDirection, Message)> requestStack = new();
}

public enum MessageDirection
{
    Received,
    Sent
}
