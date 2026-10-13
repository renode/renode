//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Network;
using Antmicro.Renode.Network.ExternalControl;

#nullable enable

namespace Antmicro.Renode.NativeInterface;

/// <summary>
/// Carries external control messages between Renode and a client library in the same process.
/// Each message holds the command, the message type and the command data.
/// </summary>
/// <remarks>
/// Each side must have at most one request chain in progress at a time, as if it served requests on one handler
/// thread like the socket transport does. One request chain of each side may be in progress at the same time.
/// Renode needs the client side of this rule, because commands such as <see cref="RunFor"/> are not safe to run
/// concurrently. A request chain is a request and every request sent while it is handled, at any depth.
/// </remarks>
public sealed unsafe class InProcessExternalControl : IDisposable, IExternal
{
    /// <summary>
    /// Opens a connection and adds it to the externals of the current emulation under <paramref name="name"/>.
    /// </summary>
    public static InProcessExternalControl Open(string name, ExternalControlRequestHandler requestHandler, void* context)
    {
        var connection = new InProcessExternalControl(requestHandler, context);
        EmulationManager.Instance.CurrentEmulation.ExternalsManager.AddExternal(connection, name, earlyDisposable: false);
        connection.opened = true;
        return connection;
    }

    /// <summary>
    /// Stores the client's response in the response box of the <see cref="SendRequest"/> call that waits for it.
    /// The client calls it through `renode_external_control_respond` while its request handler runs, with the
    /// transaction token that `SendRequest` passed to the handler.
    /// </summary>
    public static void Respond(void* responseBoxHandle, ReadOnlySpan<byte> responseBytes)
    {
        var responseBox = (StrongBox<MessagePayload?>)GCHandle.FromIntPtr((IntPtr)responseBoxHandle).Target!;
        responseBox.Value = MessagePayload.TryDecode(responseBytes, out var response) ? response : ShortMessageError(responseBytes);
    }

    public void Dispose()
    {
        // The emulation removes its externals before it disposes them, so only a close by the client finds the
        // connection still registered.
        var externals = EmulationManager.Instance.CurrentEmulation.ExternalsManager;
        if(externals.TryGetName(this, out _))
        {
            externals.RemoveExternal(this);
        }

        // Waits for `SendRequest` calls that took the lock to return. Later calls throw, so once `Dispose` returns, the
        // client can free the context that `requestHandler` receives. `SendRequest` calls inside `HandleClientRequest`
        // skip the lock, so `Dispose` must not run while `HandleClientRequest` runs.
        lock(requestChainLock)
        {
            disposed = true;
            endpoint.Dispose();
        }
    }

    /// <summary>
    /// Handles a request from the client on the calling thread.
    /// </summary>
    public MessagePayload HandleClientRequest(ReadOnlySpan<byte> requestBytes)
    {
        if(!MessagePayload.TryDecode(requestBytes, out var request))
        {
            return ShortMessageError(requestBytes);
        }

        var requestStack = threadRequestStack.Value!;
        requestStack.Push(MessageDirection.Received, request);
        MessagePayload? response = null;
        try
        {
            response = endpoint.HandleRequest(request);
            return response.Value;
        }
        finally
        {
            requestStack.Pop(MessageDirection.Sent, response);
        }
    }

    private MessagePayload SendRequest(MessagePayload request)
    {
        // The client frees `context` when the open fails, so no request may reach `requestHandler` before the open
        // succeeds.
        if(!opened)
        {
            throw new InvalidOperationException("The external control endpoint is not open yet");
        }

        var requestStack = threadRequestStack.Value!;
        // A request on this thread's stack means that this call belongs to that request's chain. Either this thread
        // holds the lock already, or the chain is the client's, and waiting for the lock would make it wait behind one
        // that Renode started on another thread.
        var startsRequestChain = requestStack.IsEmpty;
        if(startsRequestChain)
        {
            Monitor.Enter(requestChainLock);
        }

        requestStack.Push(MessageDirection.Sent, request);
        MessagePayload? response = null;
        try
        {
            if(disposed)
            {
                throw new ConnectionDisposedException();
            }

            var requestBytes = request.ToBytes().ToArray();
            // `Respond` needs a mutable object on the heap to write the response into, so we box the response.
            var responseBox = new StrongBox<MessagePayload?>();
            // The box may move, so the client gets a stable handle as its transaction token, which `Respond` turns
            // back into a reference.
            var responseBoxHandle = GCHandle.Alloc(responseBox);
            try
            {
                // Keeps the garbage collector from moving the request while the client reads it in `requestHandler`.
                fixed(byte* requestPointer = requestBytes)
                {
                    requestHandler(context, requestPointer, (uint)requestBytes.Length, (void*)GCHandle.ToIntPtr(responseBoxHandle));
                }
            }
            finally
            {
                responseBoxHandle.Free();
            }
            response = responseBox.Value ?? MessagePayload.Error(request.Command, "The client did not respond");
            return response.Value;
        }
        finally
        {
            requestStack.Pop(MessageDirection.Received, response);
            if(startsRequestChain)
            {
                Monitor.Exit(requestChainLock);
            }
        }
    }

    private InProcessExternalControl(ExternalControlRequestHandler requestHandler, void* context)
    {
        this.requestHandler = requestHandler;
        this.context = context;
        endpoint = new ExternalControlEndpoint(this, SendRequest);
        threadRequestStack = new ThreadLocal<RequestStack>(() => new RequestStack(this));
    }

    private static MessagePayload ShortMessageError(ReadOnlySpan<byte> message)
    {
        return MessagePayload.Error($"Expected at least {MessagePayload.HeaderSize} bytes of message, got {message.Length}");
    }

    private volatile bool opened;
    private volatile bool disposed;

    private readonly ExternalControlEndpoint endpoint;
    private readonly ExternalControlRequestHandler requestHandler;
    private readonly void* context;
    private readonly object requestChainLock = new object();
    private readonly ThreadLocal<RequestStack> threadRequestStack;
}
