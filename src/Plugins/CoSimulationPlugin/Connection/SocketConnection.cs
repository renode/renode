//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols;

#if !PLATFORM_WINDOWS
using Mono.Unix.Native;
#endif

namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection
{
    public class SocketConnection : ICoSimulationConnection, IEmulationElement, IDisposable
    {
        public SocketConnection(IEmulationElement parentElement, int timeoutInMilliseconds, Action<ProtocolMessage> receiveAction,
            string address = null, int mainListenPort = 0, int asyncListenPort = 0, string stdoutFile = null, string stderrFile = null, LogLevel renodeLogLevel = null)
        {
            this.parentElement = parentElement;
            this.address = address ?? DefaultAddress;
            this.stderrFile = stderrFile;
            this.stdoutFile = stdoutFile;
            this.renodeLogLevel = renodeLogLevel;
            timeout = timeoutInMilliseconds;
            receivedHandler = receiveAction;
            mainSocketCommunicator = new SocketCommunicator(parentElement, timeout, this.address, mainListenPort);
            asyncSocketCommunicator = new SocketCommunicator(parentElement, Timeout.Infinite, this.address, asyncListenPort);

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
            var success = true;
            if(!mainSocketCommunicator.AcceptConnection(timeout))
            {
                parentElement.Log(LogLevel.Error, $"Main socket failed to accept connection after timeout of {timeout}ms.");
                success = false;
            }

            if(success && !asyncSocketCommunicator.AcceptConnection(timeout))
            {
                parentElement.Log(LogLevel.Error, $"Async socket failed to accept connection after timeout of {timeout}ms.");
                success = false;
            }

            if(success && !TryHandshake())
            {
                parentElement.Log(LogLevel.Error, "Handshake with co-simulation failed.");
                success = false;
            }

            if(!success)
            {
                mainSocketCommunicator.ResetConnections();
                asyncSocketCommunicator.ResetConnections();
                KillCoSimulatedProcess();

                LogAndThrowRE($"Connection to the cosimulated peripheral failed!");
            }
            else
            {
                // If connected succesfully, listening sockets can be closed
                mainSocketCommunicator.CloseListener();
                asyncSocketCommunicator.CloseListener();

                parentElement.Log(LogLevel.Debug, "Connected to the cosimulated peripheral!");
            }

            lock(receiveThreadLock)
            {
                if(!receiveThread.IsAlive && disposeInitiated == 0)
                {
                    receiveThread.Start();
                }
            }
        }

        public bool TrySendMessage(ProtocolMessage message)
        {
            if(!IsConnected)
            {
                parentElement.Log(LogLevel.Debug, "Didn't send message {0} - not connected to co-simulation", message);
                return false;
            }
            return mainSocketCommunicator.TrySendMessage(message);
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
            return mainSocketCommunicator.TryReceiveMessage(out message);
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

            asyncSocketCommunicator.CancelCommunication();
            lock(receiveThreadLock)
            {
                if(receiveThread.IsAlive)
                {
                    receiveThread.Join(timeout);
                }
            }

            if(IsConnected)
            {
                parentElement.DebugLog("Sending 'Disconnect' message to close peripheral gracefully...");
                TrySendMessage(new ProtocolMessage(ActionType.Disconnect, 0, 0, ProtocolMessage.NoPeripheralIndex));
                mainSocketCommunicator.CancelCommunication();
            }

            if(cosimulatedProcess != null)
            {
                // Ask cosimulatedProcess to close, kill if it doesn't
                if(!cosimulatedProcess.HasExited)
                {
                    parentElement.DebugLog($"Co-simulated process '{simulationFilePath}' is still working...");
                    if(cosimulatedProcess.WaitForExit(500))
                    {
                        parentElement.DebugLog("Co-simulated process exited gracefully.");
                    }
                    else
                    {
                        KillCoSimulatedProcess();
                        parentElement.Log(LogLevel.Warning, "Co-simulated process had to be killed.");
                    }
                }
                cosimulatedProcess.Dispose();
            }

            // Close output streams
            stdoutStream?.Close();
            stderrStream?.Close();

            mainSocketCommunicator.Dispose();
            asyncSocketCommunicator.Dispose();
        }

        public bool IsConnected => mainSocketCommunicator.Connected;

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
                if(!File.Exists(simulationFilePath))
                {
                    parentElement.Log(LogLevel.Error, $"Simulation file \"{value}\" doesn't exist.");
                }
                parentElement.Log(LogLevel.Debug,
                    "Trying to run and connect to the cosimulated peripheral '{0}' through ports {1} and {2}...",
                    value, mainSocketCommunicator.ListenerPort, asyncSocketCommunicator.ListenerPort);
#if !PLATFORM_WINDOWS
                Mono.Unix.Native.Syscall.chmod(value, FilePermissions.S_IRWXU); //setting permissions to 0x700
#endif
                InitCoSimulatedProcess(value);
            }
        }

        public string ConnectionParameters
        {
            get
            {
                try
                {
                    return String.Format(this.context,
                        mainSocketCommunicator.ListenerPort, asyncSocketCommunicator.ListenerPort, address);
                }
                catch(FormatException e)
                {
                    throw new RecoverableException(e.Message);
                }
            }
        }

        private void ReceiveLoop()
        {
            while(asyncSocketCommunicator.Connected)
            {
                pauseMRES.Wait();
                if(disposeInitiated != 0)
                {
                    break;
                }
                else if(asyncSocketCommunicator.TryReceiveMessage(out var message))
                {
                    HandleReceived(message);
                }
                else
                {
                    AbortAndLogError("Connection error!");
                }
            }
        }

        private void InitCoSimulatedProcess(string filePath)
        {
            try
            {
                bool redirectStdoutToFile = !String.IsNullOrWhiteSpace(stdoutFile);
                bool redirectStderrToFile = !String.IsNullOrWhiteSpace(stderrFile);
                bool redirectOutputToLog = renodeLogLevel != null;
                cosimulatedProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(filePath)
                    {
                        UseShellExecute = false,
                        Arguments = ConnectionParameters,
                        RedirectStandardOutput = redirectStdoutToFile || redirectOutputToLog,
                        RedirectStandardError = redirectStderrToFile || redirectOutputToLog,
                    }
                };

                // Discard/write any data to prevent the stream from filling up and blocking the process
                if(redirectStdoutToFile)
                {
                    if(stdoutFile.ToLowerInvariant() != StreamDiscardConstant)
                    {
                        stdoutStream = new StreamWriter(stdoutFile);
                        cosimulatedProcess.OutputDataReceived += (s, e) => stdoutStream.WriteLine(e.Data);
                    }
                    else if(!redirectOutputToLog)
                    {
                        cosimulatedProcess.OutputDataReceived += (s, e) => { };
                    }
                }
                if(redirectStderrToFile)
                {
                    if(stderrFile.ToLowerInvariant() != StreamDiscardConstant)
                    {
                        stderrStream = new StreamWriter(stderrFile);
                        cosimulatedProcess.ErrorDataReceived += (s, e) => stderrStream.WriteLine(e.Data);
                    }
                    else if(!redirectOutputToLog)
                    {
                        cosimulatedProcess.ErrorDataReceived += (s, e) => { };
                    }
                }

                if(redirectOutputToLog)
                {
                    cosimulatedProcess.OutputDataReceived += (s, e) =>
                    {
                        if(!String.IsNullOrWhiteSpace(e.Data))
                        {
                            this.Log(renodeLogLevel, "cosimulation: {0}", e.Data);
                        }
                    };
                    cosimulatedProcess.ErrorDataReceived += (s, e) =>
                    {
                        if(!String.IsNullOrWhiteSpace(e.Data))
                        {
                            this.Log(LogLevel.Error, "cosimulation: {0}", e.Data);
                        }
                    };
                }

                cosimulatedProcess.Start();

                if(redirectStdoutToFile || redirectOutputToLog)
                {
                    cosimulatedProcess.BeginOutputReadLine();
                }
                if(redirectStderrToFile || redirectOutputToLog)
                {
                    cosimulatedProcess.BeginErrorReadLine();
                }
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

        private void KillCoSimulatedProcess()
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
            if(!TrySendMessage(new ProtocolMessage(ActionType.Handshake, 0, 0, ProtocolMessage.NoPeripheralIndex)))
            {
                parentElement.Log(LogLevel.Error, "Failed to send handshake message to co-simulation.");
                return false;
            }
            if(!TryReceiveMessage(out var result))
            {
                parentElement.Log(LogLevel.Error, "Failed to receive handshake response from co-simulation.");
                return false;
            }
            if(result.ActionId != ActionType.Handshake)
            {
                parentElement.Log(LogLevel.Error, "Invalid handshake response received from co-simulation.");
                return false;
            }

            return true;
        }

        private void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
            case ActionType.LogMessage:
                // message.Address is used to transfer log length
                if(asyncSocketCommunicator.TryReceiveString(out var log, (int)message.Address))
                {
                    parentElement.Log((LogLevel)(int)message.Data, $"Co-simulation: {log}");
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

        private StreamWriter stdoutStream;
        private StreamWriter stderrStream;

        private volatile int disposeInitiated;
        private string simulationFilePath;
        private string context = "{0} {1} {2}";
        private Process cosimulatedProcess;
        private readonly SocketCommunicator mainSocketCommunicator;
        private readonly SocketCommunicator asyncSocketCommunicator;
        private readonly Action<ProtocolMessage> receivedHandler;

        private readonly IEmulationElement parentElement;
        private readonly int timeout;
        private readonly string address;
        private readonly Thread receiveThread;
        private readonly object receiveThreadLock = new object();
        private readonly ManualResetEventSlim pauseMRES;

        private readonly string stdoutFile;
        private readonly string stderrFile;
        private readonly LogLevel renodeLogLevel;

        private const string StreamDiscardConstant = "[discard]";

        private const string DefaultAddress = "127.0.0.1";
        private const int MaxPendingConnections = 1;

        private class SocketCommunicator
        {
            public SocketCommunicator(IEmulationElement logger, int timeoutInMilliseconds, string address, int listenPort)
            {
                disposalCTS = new CancellationTokenSource();
                channelTaskFactory = new TaskFactory<int>(disposalCTS.Token);
                this.logger = logger;
                this.address = address;
                this.listenPort = listenPort;
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
#if DEBUG_LOG_COSIM_MESSAGES
                Logger.Log(LogLevel.Noisy, "Sending message to co-sim: {0}", message);
#endif
                var serializedMessage = message.Serialize();
                var size = serializedMessage.Length;
                var task = channelTaskFactory.FromAsync(
                    (callback, state) => socket.BeginSend(serializedMessage, 0, size, SocketFlags.None, callback, state),
                    socket.EndSend, state: null);

                return WaitSendOrReceiveTask(task, size);
            }

            public bool TryReceiveMessage(out ProtocolMessage message)
            {
#if DEBUG_LOG_COSIM_MESSAGES
                Logger.Log(LogLevel.Noisy, "Trying to receive message from co-sim");
#endif
                message = default(ProtocolMessage);

                var result = TryReceive(out var buffer, Marshal.SizeOf(message));
                if(result)
                {
                    message.Deserialize(buffer);
                }
#if DEBUG_LOG_COSIM_MESSAGES
                Logger.Log(LogLevel.Noisy, "Received message from co-sim: {0}", message);
#endif
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
                listener.Bind(new IPEndPoint(IPAddress.Parse(address), listenPort));

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

                if(task.Status != TaskStatus.RanToCompletion)
                {
                    if(task.Status == TaskStatus.Canceled)
                    {
                        logger.DebugLog("Send/Receive task canceled (e.g. due to removing the peripheral).");
                    }
                    else
                    {
                        logger.DebugLog("Error while trying to Send/Receive. Task status: {0}", task.Status);
                    }
                    return false;
                }

                if(task.Result != size)
                {
                    logger.DebugLog("Error while trying to Send/Receive. Unexpected number of sent/received bytes: {0} (expected {1})", task.Result, size);
                    return false;
                }
#if DEBUG_LOG_COSIM_MESSAGES
                logger.NoisyLog("Message sent/received succesfully", task.Status);
#endif
                return true;
            }

            private Socket listener;
            private Socket socket;

            private readonly int timeout;
            private readonly int listenPort;
            private readonly string address;
            private readonly CancellationTokenSource disposalCTS;
            private readonly TaskFactory<int> channelTaskFactory;
            private readonly IEmulationElement logger;
        }
    }
}