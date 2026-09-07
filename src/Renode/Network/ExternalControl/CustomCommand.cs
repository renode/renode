//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.Network.ExternalControl;

public class CustomCommand : BaseCommand
{
    public CustomCommand(ExternalControlSocket parent) : base(parent)
    {
        monitor = ObjectCreator.Instance.GetSurrogate<UserInterface.Monitor>();
    }

    public override MessagePayload Invoke(MessagePayload payload)
    {
        return payload.Type switch
        {
            CommandType.Request => HandleRequest(payload.Data),
            CommandType.EventRequest => HandleEventRequest(payload.Data),
            _ => MessagePayload.Error(Identifier, "Invalid command type"),
        };
    }

    public String Send(String command, ulong timestamp)
    {
        MessagePayload response;
        lock(commandLock)
        {
            if(!CustomCommandHandlerId.HasValue)
            {
                throw new RecoverableException("Command callback is not registered");
            }
            var eventHeader = new EventHeader { TimestampNanoseconds = timestamp};
            response = parent.SendRequest(MessagePayload.Event(Command.CustomCommand, 0, eventHeader, Encoding.UTF8.GetBytes(command)));
        }

        var commandSuccesful = response.LogOnError(Identifier, parent);
        if(!commandSuccesful)
        {
            throw new RecoverableException("Command failed");
        }

        try
        {
            var decoded_response = Encoding.UTF8.GetString(response.Data);

            return decoded_response;
        }
        catch(ArgumentException e)
        {
            var message = e.Message;
            throw new RecoverableException($"Cannot decode an error response for command {Identifier}:'{command}' due to '{message}' (raw data: {response.Data})");
        }
    }

    public void RegisterExternalCallback()
    {
        if(monitor.Interaction is not CommandInteractionWrapper)
        {
            monitor.Interaction = new CommandInteractionWrapper(monitor.Interaction);
        }

        // A Renode client can only register one event callback for CustomCommand
        const int eventId = 0;
        byte[] payload = { (byte)CustomCommandCommand.RegisterCallbacks };
        var response = parent.SendRequest(MessagePayload.Request(Command.CustomCommand, payload.Concat(BitConverter.GetBytes(eventId)).ToArray()));
        response.ThrowOnError(Command.CustomCommand);
    }

    public override Command Identifier => Command.CustomCommand;

    public int? CustomCommandHandlerId = null;

    private MessagePayload HandleEventRequest(Span<byte> data)
    {
        // Header consists of Event ID + timestamp, but timestamp is unused in Renode's implementation of CustomCommand
        const int eventHeaderSize = sizeof(ulong) + sizeof(int);
        if(data.Length < eventHeaderSize + 1)
        {
            return MessagePayload.Error(Identifier, $"Invalid data size, expected at least: {eventHeaderSize + 1} but got: {data.Length} bytes");
        }
        var eventId = BitConverter.ToInt32(data[..sizeof(int)]);
        var commandBytes = data[eventHeaderSize..];

        string command;
        try
        {
            command = Encoding.UTF8.GetString(commandBytes);
        }
        catch(ArgumentException e)
        {
            return MessagePayload.Error(Identifier, $"Cannot decode command due to '{e.Message}' (raw data: {commandBytes.ToArray()})");
        }

        parent.DebugLog("Received custom command: {0}", command);
        if(ExecuteMonitorCommand(command, out var output))
        {
            var bytes = Encoding.UTF8.GetBytes(output);
            return MessagePayload.Success(Identifier, bytes);
        }
        else
        {
            return MessagePayload.Error(Identifier, output);
        }
    }

    private MessagePayload HandleRequest(Span<byte> data)
    {
        parent.DebugLog("In CustomCommand Invoke method");
        if(data.Length != 5)
        {
            return MessagePayload.Error(Identifier, $"Expected 5 bytes payload");
        }
        var command = (CustomCommandCommand)data[0];
        parent.DebugLog("Received {0} CustomCommand command", command);

        switch(command)
        {
        case CustomCommandCommand.RegisterCallbacks:
            var ed = (int) BitConverter.ToInt32(data[1..]);
            parent.DebugLog("Attaching CustomCommand callback");
            lock(commandLock)
            {
                if(CustomCommandHandlerId.HasValue)
                {
                    parent.WarningLog("Overwriting CustomCommand handler ID {0} with {1}", CustomCommandHandlerId, ed);
                }
                CustomCommandHandlerId = ed;
            }
            break;
        default:
            return MessagePayload.Error(Identifier, "Unexpected command format");
        }
        return MessagePayload.Success(Identifier);
    }

    private bool ExecuteMonitorCommand(string command, out string output)
    {
        var interaction = monitor.Interaction as CommandInteractionWrapper;
        interaction.Clear();

        if(!monitor.Parse(command))
        {
            output = $"Could not execute command '{command}': {interaction.GetError()}";
            return false;
        }

        var error = interaction.GetError();
        if(!string.IsNullOrEmpty(error))
        {
            output = $"There was an error when executing command '{command}': {error}";
            return false;
        }

        output = interaction.GetContents();
        return true;
    }

    private readonly Object commandLock = new Object();
    private readonly Monitor monitor;

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct EventHeader
    {
        public ulong TimestampNanoseconds;
    }

    public enum CustomCommandCommand : byte
    {
        RegisterCallbacks = 0,
    }
}
