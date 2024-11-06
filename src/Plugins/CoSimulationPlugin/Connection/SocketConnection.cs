//
// Copyright (c) 2010-2024 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.ComponentModel;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;
#if !PLATFORM_WINDOWS
using Mono.Unix.Native;
#endif

namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection
{
    public class SocketConnection : ICoSimulationConnection, IDisposable
    {
        public SocketConnection(IEmulationElement parentElement, int timeoutInMilliseconds, Action<ProtocolMessage> receiveAction, string address = null)
        {
            this.parentElement = parentElement;
            this.address = address ?? DefaultAddress;
            timeout = timeoutInMilliseconds;
            receivedHandler = receiveAction;
            mainSocketComunicator = new SocketComunicator(parentElement, timeout, this.address);
            asyncSocketComunicator = new SocketComunicator(parentElement, Timeout.Infinite, this.address);

            pauseMRES = new ManualResetEventSlim(initialState: true);
            receiveThread = new Thread(ReceiveLoop)
            {
                IsBackground = true,
                Name = "CoSimulated.Receiver"
            };
        }

        public void Dispose()
        {
            Abort();
            pauseMRES.Dispose();
        }

        public void Connect()
        {
            if(!mainSocketComunicator.AcceptConnection(timeout)
                || !asyncSocketComunicator.AcceptConnection(timeout)
                || !TryHandshake())
            {
                mainSocketComunicator.ResetConnections();
                asyncSocketComunicator.ResetConnections();
                KillVerilatedProcess();

                LogAndThrowRE($"Connection to the cosimulated peripheral failed!");
            }
            else
            {
                // If connected succesfully, listening sockets can be closed
                mainSocketComunicator.CloseListener();
                asyncSocketComunicator.CloseListener();

                parentElement.Log(LogLevel.Debug, "Connected to the cosimulated peripheral!");
            }
        }

        public bool TrySendMessage(ProtocolMessage message)
        {
            if(!IsConnected)
            {
                return false;
            }
            return mainSocketComunicator.TrySendMessage(message);
        }

        public bool TryRespond(ProtocolMessage message)
        {
            if(!IsConnected)
            {
                return false;
            }
            return TrySendMessage(message);
        }

        public bool TryReceiveMessage(out ProtocolMessage message)
        {
            if(!IsConnected)
            {
                message = default(ProtocolMessage);
                return false;
            }
            return mainSocketComunicator.TryReceiveMessage(out message);
        }

        public void HandleMessage()
        {
        }

        public void Abort()
        {
            // This method is thread-safe and can be called many times.
            if(Interlocked.CompareExchange(ref disposeInitiated, 1, 0) != 0)
            {
                return;
            }

            asyncSocketComunicator.CancelCommunication();
            lock(receiveThreadLock)
            {
                if(receiveThread.IsAlive)
                {
                    Resume();
                    receiveThread.Join(timeout);
                }
            }

            if(IsConnected)
            {
                parentElement.DebugLog("Sending 'Disconnect' message to close peripheral gracefully...");
                TrySendMessage(new ProtocolMessage(ActionType.Disconnect, 0, 0));
                mainSocketComunicator.CancelCommunication();
            }

            if(cosimulatedProcess != null)
            {
                // Ask cosimulatedProcess to close, kill if it doesn't
                if(!cosimulatedProcess.HasExited)
                {
                    parentElement.DebugLog($"Verilated peripheral '{simulationFilePath}' is still working...");
                    if(cosimulatedProcess.WaitForExit(500))
                    {
                        parentElement.DebugLog("Verilated peripheral exited gracefully.");
                    }
                    else
                    {
                        KillVerilatedProcess();
                        parentElement.Log(LogLevel.Warning, "Verilated peripheral had to be killed.");
                    }
                }
                cosimulatedProcess.Dispose();
            }

            mainSocketComunicator.Dispose();
            asyncSocketComunicator.Dispose();
        }

        public void Start()
        {
            lock(receiveThreadLock)
            {
                if(!receiveThread.IsAlive && disposeInitiated == 0)
                {
                    receiveThread.Start();
                }
            }
        }

        public void Pause()
        {
            lock(pauseLock)
            {
                pauseMRES.Reset();
                IsPaused = true;
            }
        }

        public void Resume()
        {
            lock(pauseLock)
            {
                pauseMRES.Set();
                IsPaused = false;
            }
        }

        public bool IsPaused { get; private set; } = false;

        public bool IsConnected => mainSocketComunicator.Connected;

        public string Context
        {
            get
            {
                return this.context;
            }
            set
            {
                if(IsConnected)
                {
                    throw new RecoverableException("Context cannot be modified while connected");
                }
                this.context = (value == "" || value == null) ? "{0} {1} {2}" : value;
            }
        }

        public string SimulationFilePath
        {
            set
            {
                simulationFilePath = value;
                parentElement.Log(LogLevel.Debug,
                    "Trying to run and connect to the cosimulated peripheral '{0}' through ports {1} and {2}...",
                    value, mainSocketComunicator.ListenerPort, asyncSocketComunicator.ListenerPort);
#if !PLATFORM_WINDOWS
                Mono.Unix.Native.Syscall.chmod(value, FilePermissions.S_IRWXU); //setting permissions to 0x700
#endif
                InitVerilatedProcess(value);
            }
        }

        public string ConnectionParameters
        {
            get
            {
                try
                {
                    return String.Format(this.context,
                        mainSocketComunicator.ListenerPort, asyncSocketComunicator.ListenerPort, address);
                }
                catch (FormatException e)
                {
                    throw new RecoverableException(e.Message);
                }
            }
        }

        private void ReceiveLoop()
        {
            while(asyncSocketComunicator.Connected)
            {
                pauseMRES.Wait();
                if(disposeInitiated != 0)
                {
                    break;
                }
                else if(asyncSocketComunicator.TryReceiveMessage(out var message))
                {
                    HandleReceived(message);
                }
                else
                {
                    AbortAndLogError("Connection error!");
                }
            }
        }

        private void InitVerilatedProcess(string filePath)
        {
            try
            {
                cosimulatedProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(filePath)
                    {
                        UseShellExecute = false,
                        Arguments = ConnectionParameters
                    }
                };

                cosimulatedProcess.Start();
            }
            catch(Exception e)
            {
                cosimulatedProcess = null;
                LogAndThrowRE($"Error starting cosimulated peripheral!\n{e.Message}");
            }
        }

        private void LogAndThrowRE(string info)
        {
            parentElement.Log(LogLevel.Error, info);
            throw new RecoverableException(info);
        }

        private void AbortAndLogError(string message)
        {
            if(disposeInitiated != 0)
            {
                return;
            }
            parentElement.Log(LogLevel.Error, message);
            Abort();

            // Due to deadlock, we need to abort CPU instead of pausing emulation.
            throw new CpuAbortException();
        }

        private void KillVerilatedProcess()
        {
            try
            {
                cosimulatedProcess?.Kill();
            }
            catch
            {
                return;
            }
        }

        private bool TryHandshake()
        {
            return TrySendMessage(new ProtocolMessage(ActionType.Handshake, 0, 0))
                   && TryReceiveMessage(out var result)
                   && result.ActionId == ActionType.Handshake;
        }

        private void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.LogMessage:
                    // message.Address is used to transfer log length
                    if(asyncSocketComunicator.TryReceiveString(out var log, (int)message.Address))
                    {
                        parentElement.Log((LogLevel)(int)message.Data, $"Verilated peripheral: {log}");
                    }
                    else
                    {
                        parentElement.Log(LogLevel.Warning, "Failed to receive log message!");
                    }
                    break;
                default:
                    receivedHandler(message);
                    break;
            }
        }

        private volatile int disposeInitiated;
        private string simulationFilePath;
        private string context = "{0} {1} {2}";
        private Process cosimulatedProcess;
        private SocketComunicator mainSocketComunicator;
        private SocketComunicator asyncSocketComunicator;
        private Action<ProtocolMessage> receivedHandler;

        private readonly IEmulationElement parentElement;
        private readonly int timeout;
        private readonly string address;
        private readonly Thread receiveThread;
        private readonly object receiveThreadLock = new object();
        private readonly object pauseLock = new object();
        private readonly ManualResetEventSlim pauseMRES;

        private const string DefaultAddress = "127.0.0.1";
        private const int MaxPendingConnections = 1;

        private class SocketComunicator
        {
            public SocketComunicator(IEmulationElement logger, int timeoutInMilliseconds, string address)
            {
                disposalCTS = new CancellationTokenSource();
                channelTaskFactory = new TaskFactory<int>(disposalCTS.Token);
                this.logger = logger;
                this.address = address;
                timeout = timeoutInMilliseconds;
                ListenerPort = CreateListenerAndStartListening();
            }

            public void Dispose()
            {
                listener?.Close(timeout);
                socket?.Close(timeout);
                disposalCTS.Dispose();
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
                    logger.DebugLog($"Clients are pending on the listening {ListenerPort} port. Connection queue will be reset.");

                    // There's no other way to reset listener's connection queue
                    CloseListener();
                    ListenerPort = CreateListenerAndStartListening();
                }
            }

            public void CancelCommunication()
            {
                disposalCTS.Cancel();
            }

            public bool TrySendMessage(ProtocolMessage message)
            {
                var serializedMessage = message.Serialize();
                var size = serializedMessage.Length;
                var task = channelTaskFactory.FromAsync(
                    (callback, state) => socket.BeginSend(serializedMessage, 0, size, SocketFlags.None, callback, state),
                    socket.EndSend, state: null);

                return WaitSendOrReceiveTask(task, size);
            }

            public bool TryReceiveMessage(out ProtocolMessage message)
            {
                message = default(ProtocolMessage);

                var result = TryReceive(out var buffer, Marshal.SizeOf(message));
                if(result)
                {
                    message.Deserialize(buffer);
                }
                return result;
            }

            public bool TryReceiveString(out string message, int size)
            {
                message = String.Empty;
                var result = TryReceive(out var buffer, size);
                if(result)
                {
                    message = Encoding.ASCII.GetString(buffer);
                }
                return result;
            }

            public bool TryReceive(out byte[] buffer, int size)
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

            public int ListenerPort { get; private set; }
            public bool Connected => socket?.Connected ?? false;

            private int CreateListenerAndStartListening()
            {
                listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                listener.Bind(new IPEndPoint(IPAddress.Parse(address), 0));

                listener.Listen(MaxPendingConnections);
                return (listener.LocalEndPoint as IPEndPoint).Port;
            }

            private bool WaitSendOrReceiveTask(Task<int> task, int size)
            {
                try
                {
                    task.Wait(timeout, channelTaskFactory.CancellationToken);
                }
                // Exceptions thrown from the task are always packed in AggregateException
                catch(AggregateException aggregateException)
                {
                    foreach(var innerException in aggregateException.InnerExceptions)
                    {
                        logger.DebugLog("Send/Receive task exception: {0}", innerException.Message);
                    }
                }
                catch(OperationCanceledException)
                {
                    logger.DebugLog("Send/Receive task was canceled.");
                }

                if(task.Status != TaskStatus.RanToCompletion || task.Result != size)
                {
                    if(task.Status == TaskStatus.Canceled)
                    {
                        logger.DebugLog("Send/Receive task canceled (e.g. due to removing the peripheral).");
                    }
                    else
                    {
                        logger.DebugLog("Error while trying to Send/Receive!");
                    }
                    return false;
                }
                return true;
            }

            private Socket listener;
            private Socket socket;

            private readonly int timeout;
            private readonly string address;
            private readonly CancellationTokenSource disposalCTS;
            private readonly TaskFactory<int> channelTaskFactory;
            private readonly IEmulationElement logger;
        }
    }
}
