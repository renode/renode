//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

using Antmicro.Renode.Core;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class GetMachine : BaseCommand, IMachineContainer
    {
        public GetMachine(ExternalControlServer parent)
            : base(parent)
        {
            machines = new InstanceCollection<IMachine>();
        }

        public bool TryGetMachine(int id, out IMachine machine) => machines.TryGet(id, out machine);

        public override Response Invoke(List<byte> data)
        {
            if(!IInstanceBasedCommandExtensions.TryGetName(Identifier, data, 0, out var name, out var response))
            {
                return response;
            }

            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(name, out var machine))
            {
                return Response.CommandFailed(Identifier, "Machine not found");
            }

            machines.TryAdd(machine, out var id);
            return Response.Success(Identifier, id.AsRawBytes());
        }

        public override Command Identifier => Command.GetMachine;

        public override byte Version => 0x0;

        private readonly InstanceCollection<IMachine> machines;
    }

    public interface IMachineContainer
    {
        bool TryGetMachine(int id, out IMachine machine);
    }
}