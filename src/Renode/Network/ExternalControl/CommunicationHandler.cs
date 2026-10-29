//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Threading;

using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class CommunicationHandler
    {
        public CommunicationHandler(bool isExternal, ExternalControlSocket socket, ExternalControlEndpoint endpoint)
        {
            this.isExternal = isExternal;
            this.socket = socket;
            this.endpoint = endpoint;
            requestStack = new RequestStack(socket);
        }

        public void PutMessage(Message message)
        {
            lock(messageQueue)
            {
                if(messageQueue.Count > 0)
                {
                    socket.Log(LogLevel.Error, "Got message: {0} while still handling {1} messages. It may indicate an error in threading in the external simulation", message, messageQueue.Count);
                }
                messageQueue.Enqueue(message);
            }

            messageQueueNewItem.Set();
        }

        public MessagePayload SendRequest(MessagePayload payload, CancellationToken cancelationToken)
        {
            lastRequestId++;
            var message = new Message(isExternal, lastRequestId, payload);

            socket.SendMessage(message);
            requestStack.Push(MessageDirection.Sent, message);

            return HandleRequestsUntilResponse(cancelationToken).Payload;
        }

        // Handles nested requests and returns a response
        public Message HandleRequestsUntilResponse(CancellationToken cancelationToken)
        {
            while(true)
            {
                var finishedHandle = WaitHandle.WaitAny([cancelationToken.WaitHandle, messageQueueNewItem]);
                if(finishedHandle == 0)
                {
                    throw new OperationCanceledException(cancelationToken);
                }

                Message message;
                lock(messageQueue)
                {
                    message = messageQueue.Dequeue();
                }

                if(message.Payload.Type.IsRequest())
                {
                    requestStack.Push(MessageDirection.Received, message);

                    var payload = endpoint.HandleRequest(message.Payload);
                    var response = new Message(message.Id, payload);

                    socket.SendMessage(response);
                    requestStack.Pop(MessageDirection.Sent, response);
                }
                else
                {
                    requestStack.Pop(MessageDirection.Received, message);
                    return message;
                }
            }
        }

        private ushort lastRequestId = 0;

        private readonly bool isExternal;
        private readonly ExternalControlSocket socket;
        private readonly ExternalControlEndpoint endpoint;

        private readonly AutoResetEvent messageQueueNewItem = new(false);
        private readonly Queue<Message> messageQueue = new();
        private readonly RequestStack requestStack;
    }
}
