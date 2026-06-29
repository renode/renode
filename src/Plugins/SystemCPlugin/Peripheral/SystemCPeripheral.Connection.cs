//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals.SystemC
{
    public unsafe partial class SystemCPeripheral : ISystemCNativeConnection, IDisposable
    {
        public void WaitForConnection()
        {
            try
            {
                var listenerSocket = CreateListenerSocket(requestedPort);
                var assignedPort = ((IPEndPoint)listenerSocket.LocalEndPoint).Port;
                this.InfoLog("SystemCPeripheral waiting for forward SystemC connection on {0}:{1}", address, assignedPort);
                SetupConnection(listenerSocket);
                SetupTimesync();
            }
            catch(Exception e)
            {
                throw new RecoverableException($"Failed to connect to SystemC process: {e.Message}");
            }
        }

        public bool TryInitNativeConnection()
        {
            if(!useNative)
            {
                return false;
            }

            if(!NativeConfigured)
            {
                // Bridge was not configured for a native interface.
                return false;
            }
            backwardThread.Start();
            backwardThreadStarted = true;

            connectionActive = true;

            SendRequest(new RenodeMessage(RenodeAction.Init, 0, 0, 0, (ulong)timeSyncPeriodUS), out var response);
            SetupTimesync();

            return true;
        }

        public void TeardownNativeConnection()
        {
            if(backwardThreadStarted)
            {
                // Give the backward connection thread some time to gracefully shut down the TCP connection.
                backwardThread.Join(TimeSpan.FromMilliseconds(500));
            }

            connectionActive = false;

            RenodeBridgeRef = null;
            SendBackwardResponseNative = null;
            SendForwardRequestNative = null;
            SendBackwardResponseDmiNative = null;
            HandleSidebandForwardRequestNative = null;

            TeardownTimesync();
        }

        public void HandleBackwardRequestFromNative(RenodeMessage message)
        {
            bwRequest.Add(message);
        }

        public void HandleForwardResponseFromNative(RenodeMessage message)
        {
            fwResponse.Add(message);
        }

        public void HandleForwardResponseDmiFromNative(DMINativeMessage message)
        {
            dmiResponse.Add(message);
        }

        public void Dispose()
        {
            if(useNative)
            {
                TeardownNativeConnection();
            }
            else
            {
                StopSystemCProcess();
                TeardownSocketConnection();
                TeardownTimesync();
            }
        }

        public void* RenodeBridgeRef { get; set; }

        public delegate* unmanaged<void*, RenodeMessage, void> SendBackwardResponseNative { get; set; }

        public delegate* unmanaged<void*, DMIMessage, void> SendBackwardResponseDmiNative { get; set; }

        public delegate* unmanaged<void*, RenodeMessage, void> SendForwardRequestNative { get; set; }

        public delegate* unmanaged<void*, RenodeMessage, RenodeMessage> HandleSidebandForwardRequestNative { get; set; }

        public bool NativeConfigured
        {
            get
            {
                return RenodeBridgeRef != null
                    && SendBackwardResponseNative != null
                    && SendBackwardResponseDmiNative != null
                    && SendForwardRequestNative != null
                    && HandleSidebandForwardRequestNative != null
                ;
            }
        }

        public string SystemCExecutablePath
        {
            get => systemcExecutablePath;
            set
            {
                try
                {
                    systemcExecutablePath = value;
                    // For now keep sideband channel disabled by default when SystemC is started as a separate process.
                    // It can be manually overriden from script or Monitor after setting this property.
                    DisableSidebandChannel = true;
                    var listenerSocket = CreateListenerSocket(requestedPort);
                    var assignedPort = ((IPEndPoint)listenerSocket.LocalEndPoint).Port;
                    this.Log(LogLevel.Info, "SystemCPeripheral waiting for forward SystemC connection on {0}:{1}", address, assignedPort);
                    var connectionParams = $"{address} {assignedPort}";
                    StartSystemCProcess(systemcExecutablePath, connectionParams);
                    SetupConnection(listenerSocket);
                    SetupTimesync();
                }
                catch(Exception e)
                {
                    throw new RecoverableException($"Failed to start SystemC process: {e.Message}");
                }
            }
        }

        public int Port
        {
            get => requestedPort;
            set
            {
                if(value == requestedPort)
                {
                    return;
                }
                if(connectionActive)
                {
                    throw new RecoverableException($"Connection is already active on port {requestedPort}");
                }
                requestedPort = value;
            }
        }

        public string Address
        {
            get => address;
            set
            {
                if(value == address)
                {
                    return;
                }
                if(connectionActive)
                {
                    throw new RecoverableException($"Connection is already active on address {address}");
                }
                address = value;
            }
        }

        public bool UseNative
        {
            get => useNative;
            set
            {
                if(value == useNative)
                {
                    return;
                }
                if(connectionActive)
                {
                    throw new RecoverableException("Connection is already active");
                }
                useNative = value;
            }
        }

        protected void SendBackwardResponse(RenodeMessage message)
        {
            this.Log(LogLevel.Noisy, "Sending bw response. Action: {0} | Address: {1:X} | Payload: {2:X}", message.ActionId, message.Address, message.Payload);
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to send backward response using unconfigured native interface");
                    return;
                }
                SendBackwardResponseNative(RenodeBridgeRef, message);
            }
            else
            {
                try
                {
                    backwardSocket?.Send(message.Serialize(), SocketFlags.None);
                }
                catch(SocketException)
                {
                    this.Log(LogLevel.Error, "Unable to communicate with SystemC peripheral. Try setting SystemCExecutablePath first or WaitForConnection.");
                    Dispose();
                }
            }
        }

        protected void SendBackwardResponseDmi(DMIMessage message)
        {
            this.Log(LogLevel.Noisy, "Sending bw response dmi. Action: {0} | Allowed: {1} | StartAddress: {2:X} | EndAddress: {3:X}", message.ActionId, message.Allowed, message.Mapping.StartAddress, message.Mapping.EndAddress);
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to send backward response DMI using unconfigured native interface");
                    return;
                }
                SendBackwardResponseDmiNative(RenodeBridgeRef, message);
            }
            else
            {
                try
                {
                    backwardSocket?.Send(message.Serialize(), SocketFlags.None);
                }
                catch(SocketException)
                {
                    this.Log(LogLevel.Error, "Unable to communicate with SystemC peripheral. Try setting SystemCExecutablePath first or WaitForConnection.");
                    Dispose();
                }
            }
        }

        protected void SendForwardRequest(RenodeMessage message)
        {
            this.Log(LogLevel.Noisy, "Sending fw request. Action: {0} | Address: {1:X} | Payload: {2:X}", message.ActionId, message.Address, message.Payload);
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to send forward request using unconfigured native interface");
                    return;
                }
                SendForwardRequestNative(RenodeBridgeRef, message);
            }
            else
            {
                try
                {
                    forwardSocket?.Send(message.Serialize(), SocketFlags.None);
                }
                catch(SocketException)
                {
                    this.Log(LogLevel.Error, "Unable to communicate with SystemC peripheral. Try setting SystemCExecutablePath first or WaitForConnection.");
                    Dispose();
                }
            }
        }

        protected bool SendSidebandRequest(RenodeMessage request, out RenodeMessage response)
        {
            response = default;
            this.Log(LogLevel.Noisy, "Sending sideband request. Action: {0} | Address: {1:X} | Payload: {2:X}", request.ActionId, request.Address, request.Payload);
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to send sideband request using unconfigured native interface");
                    return false;
                }
                response = HandleSidebandForwardRequestNative(RenodeBridgeRef, request);
                return true;
            }
            else
            {
                try
                {
                    sidebandSocket?.Send(request.Serialize(), SocketFlags.None);
                }
                catch(SocketException)
                {
                    this.Log(LogLevel.Error, "Unable to communicate with SystemC peripheral. Try setting SystemCExecutablePath first or WaitForConnection.");
                    Dispose();
                    return false;
                }
                if(!ReceiveSidebandResponseSocket(out response))
                {
                    return false;
                }
            }

            this.Log(LogLevel.Noisy, "Received sideband response. Action: {0} | Address: {1:X} | Payload: {2:X}", response.ActionId, response.Address, response.Payload);
            return true;
        }

        protected virtual void OnUnhandledRenodeMessage(RenodeMessage message)
        {
            this.ErrorLog("SystemC integration error - invalid message type {0} sent through backward connection from the SystemC process.", message.ActionId);
        }

        private void StartSystemCProcess(string systemcExecutablePath, string connectionParams)
        {
            try
            {
                if(!RuntimeInfo.IsWindows())
                {
                    File.SetUnixFileMode(systemcExecutablePath, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
                }
                systemcProcess = new Process
                {
                    StartInfo = new ProcessStartInfo(systemcExecutablePath)
                    {
                        UseShellExecute = false,
                        Arguments = connectionParams
                    }
                };

                systemcProcess.Start();
            }
            catch(Exception e)
            {
                throw new RecoverableException(e.Message);
            }
        }

        private void StopSystemCProcess()
        {
            if(systemcProcess == null)
            {
                return;
            }

            if(systemcProcess.HasExited)
            {
                systemcProcess = null;
                return;
            }

            // Init message sent after connection has been established signifies Renode terminated and SystemC process
            // should exit.
            var request = new RenodeMessage(RenodeAction.Init, 0, 0, 0, 0);
            SendRequest(request, out var response);

            if(!systemcProcess.WaitForExit(500))
            {
                this.Log(LogLevel.Info, "SystemC process failed to exit gracefully - killing it.");
                systemcProcess.Kill();
            }
            systemcProcess = null;
        }

        private Socket CreateListenerSocket(int requestedPort)
        {
            var listenerSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            listenerSocket.Bind(new IPEndPoint(IPAddress.Parse(address), requestedPort));
            listenerSocket.Listen(2);
            return listenerSocket;
        }

        private void SetupConnection(Socket listenerSocket)
        {
            forwardSocket = listenerSocket.Accept();
            forwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for forwardSocket if the disableTimeoutCheck constructor argument is set - so if a debugger halts the SystemC process, Renode will wait for the process to restart
            if(!disableTimeoutCheck)
            {
                forwardSocket.ReceiveTimeout = 1000;
            }

            sidebandSocket = listenerSocket.Accept();
            sidebandSocket.SendTimeout = 1000;
            // No ReceiveTimeout for sidebandSocket if the disableTimeoutCheck constructor argument is set - so if a debugger halts the SystemC process, Renode will wait for the process to restart
            if(!disableTimeoutCheck)
            {
                sidebandSocket.ReceiveTimeout = 1000;
            }

            backwardSocket = listenerSocket.Accept();
            backwardSocket.SendTimeout = 1000;
            // No ReceiveTimeout for backwardSocket - it runs on a dedicated thread and by design blocks on Receive until a message arrives from SystemC process.

            listenerSocket.Close();

            backwardThread.Start();
            backwardThreadStarted = true;

            connectionActive = true;

            SendRequest(new RenodeMessage(RenodeAction.Init, 0, 0, 0, (ulong)timeSyncPeriodUS), out var response);
        }

        private void TeardownSocketConnection()
        {
            try
            {
                forwardSocket?.Shutdown(SocketShutdown.Both);
            }
            catch(SocketException ex)
            {
                this.DebugLog("Exception when shutting down forward socket: {0}", ex.Message);
            }
            try
            {
                sidebandSocket?.Shutdown(SocketShutdown.Both);
            }
            catch(SocketException ex)
            {
                this.DebugLog("Exception when shutting down sideband socket: {0}", ex.Message);
            }
            try
            {
                backwardSocket?.Shutdown(SocketShutdown.Both);
            }
            catch(SocketException ex)
            {
                this.DebugLog("Exception when shutting down backward socket: {0}", ex.Message);
            }
            if(backwardThreadStarted)
            {
                // Give the backward connection thread some time to gracefully shut down the TCP connection.
                backwardThread.Join(TimeSpan.FromMilliseconds(500));
            }

            connectionActive = false;

            forwardSocket?.Close();
            sidebandSocket?.Close();
            backwardSocket?.Close();

            forwardSocket = null;
            sidebandSocket = null;
            backwardSocket = null;
        }

        private bool ReceiveBackwardRequestNative(out RenodeMessage message)
        {
            message = new RenodeMessage();
            try
            {
                message = bwRequest.Take();
            }
            catch(InvalidOperationException)
            {
                return false;
            }
            return true;
        }

        private bool ReceiveBackwardRequestSocket(out RenodeMessage message)
        {
            message = new RenodeMessage();

            var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
            var recvBytes = new byte[messageSize];

            var nbytes = backwardSocket?.Receive(recvBytes, 0, messageSize, SocketFlags.None);
            if(nbytes == 0)
            {
                this.Log(LogLevel.Info, "Backward connection to SystemC process closed.");
                return false;
            }

            message.Deserialize(recvBytes);
            return true;
        }

        private bool ReceiveBackwardRequest(out RenodeMessage message)
        {
            message = new RenodeMessage();
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to receive bw request using unconfigured native interface");
                    return false;
                }
                if(!ReceiveBackwardRequestNative(out message))
                {
                    return false;
                }
            }
            else
            {
                if(!ReceiveBackwardRequestSocket(out message))
                {
                    return false;
                }
            }
            this.Log(LogLevel.Noisy, "Received bw request. Action: {0} | Address: {1:X} | Payload: {2:X}", message.ActionId, message.Address, message.Payload);
            return true;
        }

        private bool ReceiveForwardResponseNative(out RenodeMessage message)
        {
            message = new RenodeMessage();
            try
            {
                message = fwResponse.Take();
            }
            catch(InvalidOperationException)
            {
                return false;
            }
            return true;
        }

        private bool ReceiveForwardResponseSocket(out RenodeMessage message)
        {
            message = new RenodeMessage();

            var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
            var recvBytes = new byte[messageSize];

            var nbytes = forwardSocket?.Receive(recvBytes, 0, messageSize, SocketFlags.None);
            if(nbytes == 0)
            {
                this.Log(LogLevel.Info, "Forward connection to SystemC process closed.");
                return false;
            }

            message.Deserialize(recvBytes);
            return true;
        }

        private bool ReceiveForwardResponse(out RenodeMessage message)
        {
            message = new RenodeMessage();
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to receive fw response using unconfigured native interface");
                    return false;
                }
                if(!ReceiveForwardResponseNative(out message))
                {
                    return false;
                }
            }
            else
            {
                if(!ReceiveForwardResponseSocket(out message))
                {
                    return false;
                }
            }
            this.Log(LogLevel.Noisy, "Received fw response. Action: {0} | Address: {1:X} | Payload: {2:X}", message.ActionId, message.Address, message.Payload);
            return true;
        }

        private bool ReceiveForwardResponseDmiNative(out DMINativeMessage message)
        {
            message = new DMINativeMessage();
            try
            {
                message = dmiResponse.Take();
            }
            catch(InvalidOperationException)
            {
                return false;
            }
            return true;
        }

        private bool ReceiveForwardResponseDmiSocket(out DMINativeMessage message)
        {
            message = new DMINativeMessage();

            var messageSize = Marshal.SizeOf(typeof(DMINativeMessage));
            var recvBytes = new byte[messageSize];

            var nbytes = forwardSocket?.Receive(recvBytes, 0, messageSize, SocketFlags.None);
            if(nbytes == 0)
            {
                this.Log(LogLevel.Info, "Forward connection to SystemC process closed.");
                return false;
            }

            message.Deserialize(recvBytes);
            return true;
        }

        private bool ReceiveForwardResponseDmi(out DMINativeMessage message)
        {
            message = new DMINativeMessage();
            if(useNative)
            {
                if(!NativeConfigured)
                {
                    this.ErrorLog("Trying to receive fw response dmi using unconfigured native interface");
                    return false;
                }
                if(!ReceiveForwardResponseDmiNative(out message))
                {
                    return false;
                }
            }
            else
            {
                if(!ReceiveForwardResponseDmiSocket(out message))
                {
                    return false;
                }
            }
            this.Log(LogLevel.Noisy, "Received fw response dmi. Action: {0} | StartAddress: {1:X} | EndAddress: {2:X} | Pointer: {3:X}", message.ActionId, message.StartAddress, message.EndAddress, message.Pointer);
            return true;
        }

        private bool ReceiveSidebandResponseSocket(out RenodeMessage message)
        {
            message = new RenodeMessage();

            var messageSize = Marshal.SizeOf(typeof(RenodeMessage));
            var recvBytes = new byte[messageSize];

            var nbytes = sidebandSocket?.Receive(recvBytes, 0, messageSize, SocketFlags.None);
            if(nbytes == 0)
            {
                this.Log(LogLevel.Info, "Sideband connection to SystemC process closed.");
                return false;
            }

            message.Deserialize(recvBytes);
            return true;
        }

        private bool SendRequest(RenodeMessage request, out RenodeMessage responseMessage)
        {
            lock(messageLock)
            {
                SendForwardRequest(request);
                return ReceiveForwardResponse(out responseMessage);
            }
        }

        private bool SendDmiRequest(RenodeMessage request, out DMINativeMessage dmiNativeMessage)
        {
            lock(messageLock)
            {
                SendForwardRequest(request);
                return ReceiveForwardResponseDmi(out dmiNativeMessage);
            }
        }

        private Socket forwardSocket;
        private Socket sidebandSocket;
        private Socket backwardSocket;
        private Process systemcProcess;
        private string systemcExecutablePath;
        private string address;
        private int requestedPort;
        private bool useNative;
        private bool backwardThreadStarted;
        private bool connectionActive;

        private readonly Thread backwardThread;
        private readonly BlockingCollection<RenodeMessage> bwRequest = new BlockingCollection<RenodeMessage>(boundedCapacity: 1);
        private readonly BlockingCollection<RenodeMessage> fwResponse = new BlockingCollection<RenodeMessage>(boundedCapacity: 1);
        private readonly BlockingCollection<DMINativeMessage> dmiResponse = new BlockingCollection<DMINativeMessage>(boundedCapacity: 1);
        private readonly bool disableTimeoutCheck;
        private readonly object messageLock;
    }
}
