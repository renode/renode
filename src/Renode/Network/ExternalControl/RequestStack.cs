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

/// <summary>
/// Tracks the requests in progress in a request chain, from the request that started it to the most nested one.
/// </summary>
public class RequestStack
{
    public RequestStack(IEmulationElement owner)
    {
        this.owner = owner;
    }

    /// <summary>
    /// Adds a request that was just sent or received on top of the stack.
    /// </summary>
    public void Push(MessageDirection direction, Message request)
    {
        Push(direction, request.Payload, request.Id);
    }

    /// <summary>
    /// Adds a request that was just sent or received on top of the stack.
    /// </summary>
    public void Push(MessageDirection direction, MessagePayload request)
    {
        Push(direction, request, id: null);
    }

    /// <summary>
    /// Removes the request on top of the stack and logs each way in which the response doesn't match it.
    /// </summary>
    public void Pop(MessageDirection direction, Message response)
    {
        Pop(direction, response.Payload, response.Id);
    }

    /// <summary>
    /// Removes the request on top of the stack and logs each way in which the response doesn't match it.
    /// </summary>
    /// <param name="response">The response, or null if handling the request threw before there was one.</param>
    public void Pop(MessageDirection direction, MessagePayload? response)
    {
        if(response is null)
        {
            requests.TryPop(out _);
            return;
        }

        Pop(direction, response.Value, id: null);
    }

    public override string ToString()
    {
        var sb = new StringBuilder();

        sb.Append("Request stack (<- means received):\n");

        var depth = 0;
        foreach(var request in requests)
        {
            if(depth != 0)
            {
                sb.Append('\n');
            }

            sb.AppendFormat("{0} {1}", DirectionToString(request.Direction), Describe(request.Payload, request.Id, withData: false));
            depth++;
        }

        return sb.ToString();
    }

    public bool IsEmpty => requests.Count == 0;

    private static string DirectionToString(MessageDirection direction)
    {
        return direction == MessageDirection.Sent ? "->" : "<-";
    }

    private static string Describe(MessagePayload payload, ushort? id, bool withData)
    {
        return id.HasValue ? new Message(id.Value, payload).ToCustomString(withData) : payload.ToCustomString(withData);
    }

    private void Push(MessageDirection direction, MessagePayload request, ushort? id)
    {
        requests.Push(new Request(direction, request, id));
    }

    private void Pop(MessageDirection direction, MessagePayload response, ushort? id)
    {
        var errorMessages = new List<string>();

        if(requests.Count == 0)
        {
            errorMessages.Add("Unexpected message received");
        }
        else
        {
            var request = requests.Peek();

            if(response.Type.IsRequest())
            {
                errorMessages.Add("Unexpected request when a response is expected");
            }

            if(request.Id != id)
            {
                errorMessages.Add("Different request and response IDs");
            }

            if(request.Payload.Command != response.Command)
            {
                errorMessages.Add("Different request and response commands");
            }

            if(direction == request.Direction)
            {
                errorMessages.Add("Unexpected message");
            }
        }

        if(errorMessages.Count > 0)
        {
            owner.Log(LogLevel.Error, "{0}\nCurrently handling:\n{1} {2}\nError: {3}", this, DirectionToString(direction), Describe(response, id, withData: true), String.Join(", ", errorMessages));
        }

        requests.TryPop(out _);
    }

    private readonly IEmulationElement owner;
    private readonly Stack<Request> requests = new();

    private readonly record struct Request(MessageDirection Direction, MessagePayload Payload, ushort? Id);
}

public enum MessageDirection
{
    Received,
    Sent
}
