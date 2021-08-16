//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading;
using System.Runtime.InteropServices;
using System.Collections.Concurrent;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Utilities.Binding;
using Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols;

namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection
{
    public class DLLBasedVerilatedPeripheral : IVerilatedPeripheral, IEmulationElement
    {
        public DLLBasedVerilatedPeripheral(IEmulationElement parentElement, int timeout, Action<ProtocolMessage> receiveAction)
        {
            this.parentElement = parentElement;
            this.timeout = timeout;
            receivedHandler = receiveAction;
            mainReceived = new AutoResetEvent(initialState: false);
            senderMessages = new BlockingCollection<ProtocolMessage>();
            receiveQueue = new BlockingCollection<ProtocolMessage>();
            senderData = new BlockingCollection<string>();
            peripheralActive = new CancellationTokenSource();
            receiveSenderThread = new Thread(ReceiveLoop)
            {
                IsBackground = true,
                Name = "Verilated.Receiver"
            };
            nativeLock = new object();
        }

        public void Dispose()
        {
            peripheralActive.Cancel();
            binder?.Dispose();
            Marshal.FreeHGlobal(mainResponsePointer);
            Marshal.FreeHGlobal(senderResponsePointer);
        }

        public bool TrySendMessage(ProtocolMessage message)
        {
            if(Thread.CurrentThread.ManagedThreadId == receiveThreadId)
            {
                try
                {
                    receiveQueue.Add(message, peripheralActive.Token);
                }
                catch(OperationCanceledException)
                {
                    return false;
                }
            }
            else
            {
                lock(nativeLock)
                {
                    Marshal.StructureToPtr(message, mainResponsePointer, true);
                    handleRequest(mainResponsePointer);
                }
            }
            return true;
        }

        public bool TryReceiveMessage(out ProtocolMessage message)
        {
            if(mainReceived.WaitOne(timeout))
            {
                DebugHelper.Assert(receivedMessage.HasValue);
                message = receivedMessage.Value;
                receivedMessage = null;
                return true;
            }

            message = default(ProtocolMessage);
            return false;
        }

        public void Abort()
        {
            peripheralActive.Cancel();
        }

        public void Start()
        {
            receiveSenderThread.Start();
        }

        public void Pause()
        {
            // intentionally left empty
        }

        public void Resume()
        {
            // intentionally left empty
        }

        [Export]
        public void HandleMainMessage(IntPtr received)
        {
            // Main is used when Renode initiates communication.
            DebugHelper.Assert(!receivedMessage.HasValue);
            receivedMessage = (ProtocolMessage)Marshal.PtrToStructure(received, typeof(ProtocolMessage));
            mainReceived.Set();
        }

        [Export]
        public void HandleSenderMessage(IntPtr received)
        {
            // Sender is used when peripheral initiates communication.
            try
            {
                var message = (ProtocolMessage)Marshal.PtrToStructure(received, typeof(ProtocolMessage));
                if(message.ActionId == ActionType.LogMessage && (int)message.Address > 0)
                {
                    // ProtocolMessage doesn't allow for larger then 8 bytes data transfer, so LogMessage is
                    // treated as a special case, where:
                    // if Address is 0 then Data caries logLevel
                    // otherwise Address is a length of a cstring pointed to by Data
                    senderData.Add(Marshal.PtrToStringAuto((IntPtr)message.Data, (int)message.Address), peripheralActive.Token);
                    return;
                }
                senderMessages.Add(message, peripheralActive.Token);
            }
            catch(OperationCanceledException)
            {
                return;
            }
        }

        [Export]
        public void Receive(IntPtr messagePtr)
        {
            try
            {
                var message = receiveQueue.Take(peripheralActive.Token);
                Marshal.StructureToPtr(message, messagePtr, false);
            }
            catch(OperationCanceledException)
            {
                return;
            }
        }

        public string SimulationFilePath
        {
            get
            {
                return simulationFilePath;
            }
            set
            {
                if(value == null)
                {
                    throw new ArgumentException($"Cannot find library {value}");
                }
                lock(nativeLock)
                {
                    try
                    {
                        simulationFilePath = value;
                        binder = new NativeBinder(this, value);
                        initializeNative();
                        mainResponsePointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(ProtocolMessage)));
                        senderResponsePointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(ProtocolMessage)));
                        resetPeripheral();
                    }
                    catch
                    {
                        var info = "Error starting verilated peripheral!";
                        parentElement.Log(LogLevel.Error, info);
                        throw new RecoverableException(info);
                    }
                }
            }
        }

        private void ReceiveLoop()
        {
            receiveThreadId = Thread.CurrentThread.ManagedThreadId;
            try
            {
                while(!peripheralActive.Token.IsCancellationRequested)
                {
                    var message = senderMessages.Take(peripheralActive.Token);
                    HandleReceived(message);
                }
            }
            catch(OperationCanceledException)
            {
                return;
            }
        }

        private void HandleReceived(ProtocolMessage message)
        {
            switch(message.ActionId)
            {
                case ActionType.LogMessage:
                    try
                    {
                        var logMessage = senderData.Take(peripheralActive.Token);
                        parentElement.Log((LogLevel)(int)message.Data, logMessage);
                    }
                    catch(OperationCanceledException)
                    {
                        return;
                    }
                    break;
                default:
                    receivedHandler(message);
                    break;
            }
        }

        private int receiveThreadId;
        private string simulationFilePath;
        private NativeBinder binder;
        private IntPtr mainResponsePointer;
        private IntPtr senderResponsePointer;
        private ProtocolMessage? receivedMessage;
        private IEmulationElement parentElement;
        private Action<ProtocolMessage> receivedHandler;

        private readonly AutoResetEvent mainReceived;
        private readonly CancellationTokenSource peripheralActive;
        private readonly BlockingCollection<ProtocolMessage> senderMessages;
        private readonly BlockingCollection<ProtocolMessage> receiveQueue;
        private readonly BlockingCollection<string> senderData;
        private readonly Thread receiveSenderThread;
        private readonly int timeout;
        private readonly object nativeLock;

#pragma warning disable 649
        [Import]
        private ActionIntPtr handleRequest;
        [Import]
        private Action initializeNative;
        [Import]
        public Action resetPeripheral;
#pragma warning restore 649
    }
}
