//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

// Receives each request that Renode sends to the client. Its parameters, in order:
// - `void* context`: the context passed to `renode_external_control_open`.
// - `byte* message`: the request. The pointer is valid only during the call.
// - `uint size`: the size of the request in bytes.
// - `void* transactionToken`: the transaction token to pass to `renode_external_control_respond`.
global using unsafe ExternalControlRequestHandler = delegate* unmanaged<void*, byte*, uint, void*, void>;

// Receives the response to a request from the client. Its parameters, in order:
// - `void* context`: the context passed to `renode_external_control_request`.
// - `byte* message`: the response. The pointer is valid only during the call.
// - `uint size`: the size of the response in bytes.
global using unsafe ExternalControlResponseHandler = delegate* unmanaged<void*, byte*, uint, void>;

using System;
using System.Linq;
using System.Runtime.InteropServices;

#nullable enable

namespace Antmicro.Renode.NativeInterface;

public static unsafe partial class NativeExports
{
    /// <summary>
    /// Opens an external control endpoint for a client library in this process, and adds it to the externals of the
    /// current emulation under <paramref name="name"/>.
    /// Renode calls <paramref name="requestHandler"/> with each request it sends to the client, and the client
    /// responds with `renode_external_control_respond` before the handler returns. Renode sends no request before
    /// this call succeeds.
    /// When <paramref name="serializeRequests"/> is not zero, Renode holds the requests that start a request chain
    /// until no client request is in progress. See <see cref="InProcessExternalControl"/>.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_external_control_open")]
    [return: DNNE.C99Type("RenodeStatus")]
    [DNNE.C99DeclCode("""
                      // Opaque handle to an external control endpoint inside Renode
                      typedef struct RenodeExternalControl RenodeExternalControl;
                      // Opaque token for a request from Renode, which the client passes back with its response
                      typedef struct RenodeExternalControlTransactionToken RenodeExternalControlTransactionToken;
                      typedef void (*RenodeExternalControlRequestHandler)(void *context, const uint8_t *message, uint32_t size, RenodeExternalControlTransactionToken *transaction_token);
                      typedef void (*RenodeExternalControlResponseHandler)(void *context, const uint8_t *message, uint32_t size);
                      """)]
    public static NativeStatus ExternalControlOpen(
        [DNNE.C99Type("const char *")] byte* name,
        [DNNE.C99Type("RenodeExternalControlRequestHandler")] ExternalControlRequestHandler requestHandler,
        [DNNE.C99Type("void *")] void* context,
        byte serializeRequests,
        [DNNE.C99Type("RenodeExternalControl **")] void** endpoint
    )
    {
        if(name == null || requestHandler == null || endpoint == null)
        {
            Console.Error.WriteLine("A name, a request handler and an endpoint pointer are required");
            return NativeStatus.CommandError;
        }

        try
        {
            var instance = InProcessExternalControl.Open(Marshal.PtrToStringUTF8((IntPtr)name)!, requestHandler, context, serializeRequests != 0);
            // The emulation drops the endpoint when it is cleared, but the client still uses it until it closes it, so
            // the handle stops the garbage collector from collecting it until `ExternalControlClose` frees the handle.
            // It also gives the client a stable pointer that the other exports turn back into a reference.
            *endpoint = (void*)GCHandle.ToIntPtr(GCHandle.Alloc(instance));
            return NativeStatus.Success;
        }
        catch(Exception ex)
        {
            Console.Error.WriteLine($"Exception: {ex}");
            return NativeStatus.Exception;
        }
    }

    /// <summary>
    /// Handles a request from the client on the calling thread.
    /// Passes the response to <paramref name="responseHandler"/> before it returns.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_external_control_request")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus ExternalControlRequest(
        [DNNE.C99Type("RenodeExternalControl *")] void* endpoint,
        [DNNE.C99Type("const uint8_t *")] byte* message,
        uint size,
        [DNNE.C99Type("RenodeExternalControlResponseHandler")] ExternalControlResponseHandler responseHandler,
        [DNNE.C99Type("void *")] void* context
    )
    {
        try
        {
            var instance = (InProcessExternalControl)GCHandle.FromIntPtr((IntPtr)endpoint).Target!;
            var response = instance.HandleClientRequest(new ReadOnlySpan<byte>(message, (int)size)).ToBytes().ToArray();
            // Keeps the garbage collector from moving the response while the client reads it in `responseHandler`.
            fixed(byte* responsePointer = response)
            {
                responseHandler(context, responsePointer, (uint)response.Length);
            }
            return NativeStatus.Success;
        }
        catch(Exception ex)
        {
            Console.Error.WriteLine($"Exception: {ex}");
            return NativeStatus.Exception;
        }
    }

    /// <summary>
    /// Responds to the request from Renode that the transaction token names. Call it from the request handler, before
    /// it returns.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_external_control_respond")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus ExternalControlRespond(
        [DNNE.C99Type("RenodeExternalControlTransactionToken *")] void* transactionToken,
        [DNNE.C99Type("const uint8_t *")] byte* message,
        uint size
    )
    {
        try
        {
            InProcessExternalControl.Respond(transactionToken, new ReadOnlySpan<byte>(message, (int)size));
            return NativeStatus.Success;
        }
        catch(Exception ex)
        {
            Console.Error.WriteLine($"Exception: {ex}");
            return NativeStatus.Exception;
        }
    }

    /// <summary>
    /// Closes the endpoint. Renode sends no new requests through it after it returns.
    /// Call it only when no call to `renode_external_control_request` is in progress.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_external_control_close")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus ExternalControlClose([DNNE.C99Type("RenodeExternalControl *")] void* endpoint)
    {
        try
        {
            var handle = GCHandle.FromIntPtr((IntPtr)endpoint);
            ((InProcessExternalControl)handle.Target!).Dispose();
            handle.Free();
            return NativeStatus.Success;
        }
        catch(Exception ex)
        {
            Console.Error.WriteLine($"Exception: {ex}");
            return NativeStatus.Exception;
        }
    }
}
