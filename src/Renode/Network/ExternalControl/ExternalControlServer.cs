//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network
{
    public static class ExternalControlServerExtensions
    {
        public static void CreateExternalControlServer(this Emulation emulation, string name, uint port)
        {
            emulation.ExternalsManager.AddExternal(new ExternalControlServer(emulation, port), name);
        }
    }

    public class ExternalControlServer : IDisposable, IExternal
    {
        public ExternalControlServer(Emulation emulation, uint port)
        {
            this.emulation = emulation;
            magic = Encoding.ASCII.GetBytes(new[] { 'R', 'E'});

            socketServerProvider.ConnectionAccepted += delegate
            {
                DebugLog("Connection established");
            };
            socketServerProvider.ConnectionClosed += delegate
            {
                DebugLog("Connection closed");
            };

            socketServerProvider.DataReceived += OnByteWritten;
            socketServerProvider.Start((int)port);

            Log(LogLevel.Info, "Listening on port {0}", port);
        }

        public void Dispose()
        {
            socketServerProvider.Stop();
        }

        public bool DebugLogsEnabled { get; set; }

        private Response HandleCommand(Commands command)
        {
            Response response;
            switch(command)
            {
                case Commands.CurrentTime:
                    throw new RecoverableException("Getting current time isn't implemented yet");
                case Commands.RunFor:
                    var microseconds = BitConverter.ToUInt64(buffer.ToArray(), 0);
                    var interval = TimeInterval.FromMicroseconds(microseconds);
                    Log(LogLevel.Info, "Executing RunFor({0}s) command)", interval);
                    emulation.RunFor(interval);
                    response = Response.Success(command);
                    break;
                default:
                    return Response.InvalidCommand(command);
            }
            return response;
        }

        private void Log(LogLevel type, string message, params object[] args)
        {
            Logger.Log(type, $"{nameof(ExternalControlServer)}: {message}", args);
        }

        private void DebugLog(string message, params object[] args)
        {
            if(DebugLogsEnabled)
            {
                Log(LogLevel.Info, message, args);
            }
        }

        private void OnByteWritten(int value)
        {
            DebugLog("Received 0x{0:X}; buffer: {1}", value, Misc.PrettyPrintCollectionHex(buffer));
            var oldState = state;
            switch(state)
            {
                // Currently Init is equivalent to WaitingForMagic.
                case States.Init:
                //     // Check client compatibility ?? Maybe set version for each command to only limit
                //     // using them instead of blocking all of the commands? Or just inform?
                //     break;
                // Let's make sure nothing's messed up.
                case States.WaitingForMagic:
                    var nextMagicByte = magic[magicBytesReceived];
                    if(value != nextMagicByte)
                    {
                        Log(LogLevel.Error, "Invalid command magic byte {0}: 0x{1:X}; should be: 0x{2:X}", magicBytesReceived, value, nextMagicByte);

                        // TODO: Abort server?
                        magicBytesReceived = 0;
                        SendResponse(Response.FatalError($"Invalid magic byte {magicBytesReceived}: 0x{nextMagicByte:X}"));
                        break;
                    }

                    if(++magicBytesReceived == magic.Length)
                    {
                        magicBytesReceived = 0;
                        state = States.WaitingForCommand;
                    }
                    break;
                case States.WaitingForCommand:
                    command = (Commands)(byte)value;
                    state = States.WaitingForDataSize;
                    break;
                case States.WaitingForDataSize:
                    buffer.Add((byte)value);
                    if(buffer.Count == sizeof(uint))
                    {
                        dataSize = BitConverter.ToUInt32(buffer.ToArray(), 0);
                        state = dataSize > 0 ? States.WaitingForData : States.Executing;
                    }
                    break;
                case States.WaitingForData:
                    buffer.Add((byte)value);
                    if(buffer.Count == dataSize)
                    {
                        state = States.Executing;
                    }
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(state), "Invalid state");
            }

            if(oldState != state && (state == States.WaitingForDataSize || state == States.WaitingForData))
            {
                buffer.Clear();
            }

            if(state == States.Executing)
            {
                Response response;
                try
                {
                    response = HandleCommand(command);
                }
                catch(RecoverableException e)
                {
                    Log(LogLevel.Error, "{0} command error: {1}", command, e.Message);
                    response = Response.CommandFailed(command, e.Message);
                }
                SendResponse(response);
                state = States.WaitingForMagic;
            }
        }

        private void SendResponse(Response response)
        {
            var bytes = response.GetBytes();
            socketServerProvider.Send(bytes);
            DebugLog("Response sent: {0}; bytes: {1}", response, Misc.PrettyPrintCollectionHex(bytes));
        }

        private Commands command;
        private uint dataSize;
        private uint magicBytesReceived;
        private States state = States.Init;

        private readonly List<byte> buffer = new List<byte>();
        private readonly Emulation emulation;
        private readonly byte[] magic;
        private readonly SocketServerProvider socketServerProvider = new SocketServerProvider(emitConfigBytes: false);

        private class Response
        {
            public static Response CommandFailed(Commands command, string reason)
            {
                return new Response(ReturnCodes.CommandFailed, command, text: reason);
            }

            public static Response FatalError(string reason)
            {
                return new Response(ReturnCodes.FatalError, text: reason);
            }

            public static Response InvalidCommand(Commands command)
            {
                return new Response(ReturnCodes.InvalidCommand, command);
            }

            public static Response Success(Commands command)
            {
                return new Response(ReturnCodes.SuccessWithoutData, command);
            }

            public static Response Success(Commands command, IEnumerable<byte> data = null)
            {
                return new Response(ReturnCodes.SuccessWithoutData, command, data);
            }

            public static Response Success(Commands command, string text)
            {
                return new Response(ReturnCodes.SuccessWithoutData, command, text: text);
            }

            private Response(ReturnCodes returnCode, Commands? command = null, IEnumerable<byte> data = null, string text = null)
            {
                DebugHelper.Assert(command != null || returnCode == ReturnCodes.FatalError);  // Command can be null only for FatalError.

                this.returnCode = returnCode;
                this.command = command;

                if(data != null)
                {
                    // Only one of data/text should be set. TODO? Maybe let's better make response type Generic?
                    DebugHelper.Assert(text == null);
                    this.data = data;
                }
                else
                {
                    this.text = text;
                }
            }

            public IEnumerable<byte> GetBytes()
            {
                var response = new List<byte> { (byte)returnCode };
                if(command.HasValue)
                {
                    response.Add((byte)command);
                }

                IEnumerable<byte> dataBytes = null;
                if(data != null)
                {
                    dataBytes = data;
                }
                else if(text != null)
                {
                    dataBytes = Encoding.ASCII.GetBytes(text);
                }

                if(dataBytes != null && dataBytes.Any())
                {
                    response.AddRange(checked((uint)dataBytes.Count()).AsRawBytes());
                    response.AddRange(dataBytes);
                }
                return response;
            }

            public override string ToString()
            {
                return new StringBuilder("Response(")
                    .Append(returnCode)
                    .Append(", command: ")
                    .Append(command)
                    .Append(", data: ")
                    .Append(text ?? Misc.PrettyPrintCollectionHex(data))
                    .Append(')')
                    .ToString();
            }

            private readonly Commands? command;
            private readonly IEnumerable<byte> data;
            private readonly ReturnCodes returnCode;
            private readonly string text;

            private enum ReturnCodes : byte
            {
                CommandFailed,
                FatalError,
                InvalidCommand,
                SuccessWithData,
                SuccessWithoutData,
            }
        }

        private enum Commands : byte
        {
            CurrentTime,
            RunFor,
        }

        private enum States
        {
            Executing,
            Init,
            WaitingForCommand,
            WaitingForData,
            WaitingForDataSize,
            WaitingForMagic,
        }
    }
}
