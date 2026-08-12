//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;

using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class CommunicationHandler : IEmulationElement
    {
        public CommunicationHandler(bool isExternal, ExternalControlServer server)
        {
            this.isExternal = isExternal;
            this.server = server;
        }

        public void PutMessage(Message message)
        {
            lock(messageQueue)
            {
                if(messageQueue.Count > 0)
                {
                    this.Log(LogLevel.Error, "Got message: {0} while still handling {1} messages. It may indicate an error in threading in the external simulation", message, messageQueue.Count);
                }
                messageQueue.Enqueue(message);
            }

            messageQueueNewItem.Set();
        }

        public MessagePayload SendRequest(MessagePayload payload, CancellationToken cancelationToken)
        {
            lastRequestId++;
            var message = new Message(isExternal, lastRequestId, payload);

            server.SendMessage(message);
            requestStack.Push((MessageDirection.Sent, message));

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
                    requestStack.Push((MessageDirection.Received, message));

                    MessagePayload payload;
                    var command = message.Payload.Command;
                    var handler = server.GetCommandHandler(command);

                    if(handler == null)
                    {
                        payload = MessagePayload.InvalidCommand(command);
                        server.Log(LogLevel.Error, "Invalid command received: {0}", command);
                    }
                    else
                    {
                        try
                        {
                            payload = handler.Invoke(new List<byte>(message.Payload.Data));
                        }
                        catch(RecoverableException e)
                        {
                            payload = MessagePayload.Error(command, e.Message);
                            server.Log(LogLevel.Error, "{0} command failed: {1}", command, e.Message);
                        }
                    }

                    var response = new Message(message.Id, payload);

                    server.SendMessage(response);
                    PopFromStack(MessageDirection.Sent, response);
                }
                else
                {
                    PopFromStack(MessageDirection.Received, message);
                    return message;
                }
            }
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

        private void PopFromStack(MessageDirection direction, Message response)
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
                this.Log(LogLevel.Error, "{0}\nCurrently handling:\n{1} {2}\nError: {3}", this, DirectionToString(direction), response, String.Join(", ", errorMessages));
            }

            requestStack.TryPop(out _);
        }

        private ushort lastRequestId = 0;

        private readonly bool isExternal;
        private readonly ExternalControlServer server;

        private readonly AutoResetEvent messageQueueNewItem = new(false);
        private readonly Queue<Message> messageQueue = new();
        private readonly Stack<(MessageDirection, Message)> requestStack = new();

        private enum MessageDirection
        {
            Received,
            Sent
        }
    }
}
