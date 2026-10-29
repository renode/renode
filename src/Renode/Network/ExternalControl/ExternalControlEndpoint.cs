//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Network.ExternalControl;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

#nullable enable

namespace Antmicro.Renode.Network;

/// <summary>
/// One end of an external control connection. It runs the commands that the other end requests and sends requests to
/// the other end. The transport that carries the connection's messages owns it.
/// </summary>
public sealed class ExternalControlEndpoint : IDisposable
{
    public ExternalControlEndpoint(IEmulationElement owner, Func<MessagePayload, MessagePayload> sendRequest)
    {
        Owner = owner;
        this.sendRequest = sendRequest;

        var getMachineHandler = new GetMachine(this);
        Machines = getMachineHandler;

        commandHandlers = new ICommand[]
        {
            new TimeElapsedCallbackCommand(this),
            new RunFor(this),
            new GetTime(this),
            new SPI(this),
            new ADC(this),
            new GPIOPort(this),
            new SystemBus(this),
            new CheckVersion(this),
            new CANBus(this),
            new CustomCommand(this),
            getMachineHandler,
        }.ToDictionary(handler => handler.Identifier);
    }

    public ICommand? GetCommandHandler(Command command)
    {
        if(!commandHandlers.TryGetValue(command, out var handler))
        {
            return null;
        }
        return handler;
    }

    public void SynchronizeTimeWithExternal()
    {
        RegisterTimeElapsedCallback((timeStamp) => EmulationManager.Instance.CurrentEmulation.RunUntil(timeStamp.TimeElapsed));
    }

    public void RegisterTimeElapsedCallback(Action<TimeStamp> callback)
    {
        GetCommandHandler<TimeElapsedCallbackCommand>(Command.TimeElapsedCallback).RegisterExternalCallback(callback);
    }

    public void ConnectExternalGPIOOutput(IGPIOReceiver gpioReceiver, int pinId, string externalMachine, string externalGPIO, int externalPinId)
    {
        var machine = gpioReceiver.GetMachine();
        RegisterExternalGPIOChangeCallback(externalMachine, externalGPIO, externalPinId, (externalEventTimestamp, state) =>
        {
            machine.HandleTimeDomainEvent(gpioReceiver.OnGPIO, pinId, state, externalEventTimestamp);
        });
    }

    public void RegisterExternalGPIOChangeCallback(string externalMachine, string externalGPIO, int externalPinId, Action<TimeStamp, bool> callback)
    {
        var machineId = GetCommandHandler<GetMachine>(Command.GetMachine).GetExternalMachineId(externalMachine);
        GetCommandHandler<GPIOPort>(Command.GPIOPort).RegisterExternalCallback(machineId, externalGPIO, externalPinId, callback);
    }

    public void AttachCustomCommandCallbackToMonitor()
    {
        GetCommandHandler<CustomCommand>(Command.CustomCommand).RegisterExternalCallback();
    }

    public void RegisterRemoteBusPeripheral(string localMachineName, string remoteMachineName, string remotePeripheralName, SystemBus.AccessWidth accessWidth, SystemBus.AccessType accessType, string? localContextName = null)
    {
        try
        {
            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(localMachineName, out var machine))
            {
                throw new RecoverableException($"No machine with name: {localMachineName} was found");
            }

            IPeripheral? localContextPeripheral = null;
            if(localContextName is not null && !machine.TryGetByName<IPeripheral>(localContextName, out localContextPeripheral))
            {
                throw new RecoverableException($"No peripheral with name: {localContextName} was found");
            }

            var command = GetCommandHandler<SystemBus>(Command.SystemBus);

            var response = this.SendRequest(MessagePayload.Request(Command.GetMachine, remoteMachineName));
            response.LogOnError(command.Identifier, Owner);
            if(response.Type != CommandType.Success)
            {
                throw new RecoverableException($"Remote Renode doesn't have the machine named: {remoteMachineName}");
            }
            var remoteMachineId = BitConverter.ToInt32(response.Data);

            // Sends a request to get remote peripheral id
            response = SendRemoteRegisterRequest(remoteMachineId, remotePeripheralName);
            if(response.Type != CommandType.Success)
            {
                throw new RecoverableException($"Remote Renode doesn't have the peripheral named: {remotePeripheralName}");
            }
            var remotePeripheralId = BitConverter.ToInt32(response.Data);

            command.RegisterRemoteCallback(remotePeripheralId, accessWidth, accessType, machine, localContextPeripheral);
        }
        catch(Exception e)
        {
            // catch any exception, log it, then forward to Monitor
            Owner.ErrorLog("Failed to register remote callback: {0}", e.Message);
            throw;
        }
    }

    public String SendCustomCommand(String command)
    {
        var customCommand = GetCommandHandler<CustomCommand>(Command.CustomCommand);
        var timestamp = EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime.TotalNanoseconds;
        return customCommand.Send(command, timestamp);
    }

    public void Dispose()
    {
        foreach(var handler in commandHandlers.Values.OfType<IDisposable>())
        {
            handler.Dispose();
        }
        commandHandlers.Clear();
    }

    /// <summary>
    /// Sends a request to the other end and returns its response.
    /// </summary>
    public MessagePayload SendRequest(MessagePayload request)
    {
        return sendRequest(request);
    }

    /// <summary>
    /// The transport that owns this endpoint. Commands log through it, so that their messages carry its name.
    /// </summary>
    public IEmulationElement Owner { get; }

    public IMachineContainer Machines { get; }

    private T GetCommandHandler<T>(Command command) where T : ICommand
    {
        return (T)commandHandlers[command];
    }

    private MessagePayload SendRemoteRegisterRequest(int remoteMachineId, string remotePeripheralName)
    {
        return this.SendRequest(MessagePayload.Request(Command.SystemBus, new RemoteBusRegistrationRequest(remoteMachineId, remotePeripheralName).GetRawBytes()));
    }

    private readonly Dictionary<Command, ICommand> commandHandlers;
    private readonly Func<MessagePayload, MessagePayload> sendRequest;

    private struct RemoteBusRegistrationRequest
    {
        public RemoteBusRegistrationRequest(int remoteMachineId, string remotePeripheralName)
        {
            nameBytes = Encoding.UTF8.GetBytes(remotePeripheralName);
            internals = new Internals(-1, remoteMachineId, nameBytes.Length);
        }

        public byte[] GetRawBytes()
        {
            return internals.AsRawBytes().Concat(nameBytes).ToArray();
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private record struct Internals(int Id, int RemoteMachineId, int NameLength);

        private readonly Internals internals;
        // Array size cannot be inferred at runtime by Marshal.SizeOf, so it remains outside
        private readonly byte[] nameBytes;
    }
}
