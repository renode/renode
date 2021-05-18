//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;
using System.Threading;
using System.Threading.Tasks;
using Antmicro.Renode.Logging;
using System.Runtime.InteropServices;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class CommunicationChannel : IDisposable
    {
        public CommunicationChannel(IEmulationElement parentElement, int timeoutInMilliseconds)
        {
            disposalCTS = new CancellationTokenSource();
            channelTaskFactory = new TaskFactory<int>(disposalCTS.Token);
            logElement = parentElement;
            timeout = timeoutInMilliseconds;

            ListenerPort = CreateListenerAndStartListening();
        }

        public bool AcceptConnection(int timeoutInMilliseconds)
        {
            // Check if there's any connection waiting to be accepted (with timeout in MICROseconds)
            var acceptAttempt = listener.Poll(timeoutInMilliseconds * 1000, SelectMode.SelectRead);
            if(acceptAttempt)
            {
                socket = listener.Accept();
            }
            return acceptAttempt;
        }

        public void CloseListener()
        {
            listener.Close();
            listener = null;
        }

        public void ResetConnections()
        {
            socket?.Close();

            if(listener.Poll(0, SelectMode.SelectRead))
            {
                logElement.DebugLog($"Clients are pending on the listening {ListenerPort} port. Connection queue will be reset.");

                // There's no other way to reset listener's connection queue
                CloseListener();
                ListenerPort = CreateListenerAndStartListening();
            }
        }

        public void CancelCommunication()
        {
            disposalCTS.Cancel();
        }

        public bool SendMessage(ProtocolMessage message)
        {
            var serializedMessage = message.Serialize();
            var size = serializedMessage.Length;
            var task = channelTaskFactory.FromAsync(
                (callback, state) => socket.BeginSend(serializedMessage, 0, size, SocketFlags.None, callback, state),
                socket.EndSend, state: null);

            return WaitSendOrReceiveTask(task, size);
        }

        public bool ReceiveMessage(out ProtocolMessage message)
        {
            message = new ProtocolMessage();

            var result = Receive(out var buffer, Marshal.SizeOf(message));
            if(result)
            {
                message.Deserialize(buffer);
            }
            return result;
        }

        public bool ReceiveString(out string message, int size)
        {
            message = String.Empty;
            var result = Receive(out var buffer, size);
            if(result)
            {
                message = Encoding.ASCII.GetString(buffer);
            }
            return result;
        }

        public void Dispose()
        {
            listener?.Close(timeout);
            socket?.Close(timeout);
            disposalCTS.Dispose();
        }

        public bool Connected => socket.Connected;
        public int ListenerPort { get; private set; }

        private int CreateListenerAndStartListening()
        {
            listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listener.Bind(new IPEndPoint(IPAddress.Parse(Address), 0));

            listener.Listen(MaxPendingConnections);
            return (listener.LocalEndPoint as IPEndPoint).Port;
        }

        private bool Receive(out byte[] buffer, int size)
        {
            buffer = null;
            var taskBuffer = new byte[size];
            var task = channelTaskFactory.FromAsync(
                (callback, state) => socket.BeginReceive(taskBuffer, 0, size, SocketFlags.None, callback, state),
                socket.EndReceive, state: null);

            var isSuccess = WaitSendOrReceiveTask(task, size);
            if(isSuccess)
            {
                buffer = taskBuffer;
            }
            return isSuccess;
        }

        private bool WaitSendOrReceiveTask(Task<int> task, int size)
        {
            try
            {
                task.Wait(timeout);
            }
            // Exceptions thrown from the task are always packed in AggregateException
            catch(AggregateException aggregateException)
            {
                foreach(var innerException in aggregateException.InnerExceptions)
                {
                    logElement.DebugLog("Send/Receive task exception: {0}", innerException.Message);
                }
            }

            if(task.Status != TaskStatus.RanToCompletion || task.Result != size)
            {
                if(task.Status == TaskStatus.Canceled)
                {
                    logElement.DebugLog("Send/Receive task canceled (e.g. due to removing the peripheral).");
                }
                else
                {
                    logElement.DebugLog("Error while trying to Send/Receive!");
                }
                return false;
            }
            return true;
        }

        private Socket listener;
        private Socket socket;

        private readonly CancellationTokenSource disposalCTS;
        private readonly TaskFactory<int> channelTaskFactory;
        private readonly IEmulationElement logElement;
        private readonly int timeout;

        private const string Address = "127.0.0.1";
        private const int MaxPendingConnections = 1;
    }
}
