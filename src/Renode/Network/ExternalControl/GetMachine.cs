//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class GetMachine : BaseCommand, IMachineContainer
    {
        public GetMachine(ExternalControlSocket parent)
            : base(parent)
        {
            machines = new InstanceCollection<IMachine>();
        }

        public int GetExternalMachineId(string externalMachine)
        {
            var data = IInstanceBasedCommandExtensions.EncodeString(externalMachine);
            var response = parent.SendRequest(new MessagePayload(Identifier, CommandType.Request, data.ToArray()));
            response.ThrowOnError(Identifier);

            if(response.Data.Length != sizeof(int))
            {
                throw new RecoverableException("Unexpected length of response: {response}");
            }

            return BitConverter.ToInt32(response.Data);
        }

        public bool TryGetMachine(int id, out IMachine machine)
        {
            lock(machines)
            {
                return machines.TryGet(id, out machine);
            }
        }

        public override MessagePayload Invoke(MessagePayload payload)
        {
            if(!IInstanceBasedCommandExtensions.TryGetName(Identifier, payload.Data, 0, out var name, out var response))
            {
                return response;
            }

            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(name, out var machine))
            {
                return MessagePayload.Error(Identifier, "Machine not found");
            }

            lock(machines)
            {
                machines.TryAdd(machine, out var id);
                return MessagePayload.Success(Identifier, id.AsRawBytes());
            }
        }

        public override Command Identifier => Command.GetMachine;

        private readonly InstanceCollection<IMachine> machines;
    }

    public interface IMachineContainer
    {
        bool TryGetMachine(int id, out IMachine machine);
    }
}
