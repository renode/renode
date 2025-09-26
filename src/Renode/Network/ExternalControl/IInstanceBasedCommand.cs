//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Network.ExternalControl
{
    public static class IInstanceBasedCommandExtensions
    {
        public static bool TryGetName(Command command, List<byte> data, int offset, out string name, out Response response)
        {
            name = default(string);
            response = default(Response);

            if(!TryDecodeNameLength(command, data, offset, out var length, out response))
            {
                return false;
            }

            return TryDecodeName(command, data, offset + NameLengthSize, length, out name, out response);
        }

        public static Response InvokeHandledWithInstance<T>(this IInstanceBasedCommand<T> @this, List<byte> data, Predicate<T> instanceFilter = null)
            where T : IEmulationElement
        {
            if(data.Count < PayloadOffset)
            {
                return Response.CommandFailed(@this.Identifier, $"Expected at least {PayloadOffset} bytes of payload");
            }
            var id = BitConverter.ToInt32(data.GetRange(InstanceIdOffset, InstanceIdSize).ToArray(), 0);

            // only non-negative instance ids are valid
            if(id >= 0 && @this.Instances.TryGet(id, out var instance))
            {
                return @this.Invoke(instance, data.GetRange(PayloadOffset, data.Count - PayloadOffset));
            }

            // id set to a magic of -1 is used to register a new instance
            if(id != -1)
            {
                return Response.CommandFailed(@this.Identifier, "Invalid instance id");
            }

            // requested instance registration

            if(!TryGetMachine(@this, data, out var machine, out var response))
            {
                return response;
            }

            if(!TryGetName(@this.Identifier, data, NameOffset, out var name, out response))
            {
                return response;
            }

            if(!@this.TryRegisterInstance(machine, name, instanceFilter, out id))
            {
                return Response.CommandFailed(@this.Identifier, "Instance not found");
            }

            return Response.Success(@this.Identifier, id.AsRawBytes());
        }

        public const int HeaderSize = InstanceIdSize;

        private static bool TryRegisterInstance<T>(this IInstanceBasedCommand<T> @this, IMachine machine, string name, Predicate<T> instanceFilter, out int id)
            where T : IEmulationElement
        {
            id = default(int);
            if(!EmulationManager.Instance.CurrentEmulation.TryGetEmulationElementByName(name, machine, out var instance))
            {
                return false;
            }

            if(!(instance is T) || (!instanceFilter?.Invoke((T)instance) ?? false))
            {
                return false;
            }

            @this.Instances.TryAdd((T)instance, out id);
            return true;
        }

        private static bool TryGetMachine(this ICommand @this, List<byte> data, out IMachine machine, out Response response)
        {
            machine = default(IMachine);
            response = default(Response);

            if(data.Count < MachineIdOffset + MachineIdSize)
            {
                response = Response.CommandFailed(@this.Identifier, $"Expected at least {MachineIdOffset + MachineIdSize} bytes of payload");
                return false;
            }

            var id = BitConverter.ToInt32(data.GetRange(MachineIdOffset, MachineIdSize).ToArray(), 0);
            if(@this.Machines?.TryGetMachine(id, out machine) ?? false)
            {
                return true;
            }

            response = Response.CommandFailed(@this.Identifier, "Invalid machine id");
            return false;
        }

        private static bool TryDecodeNameLength(Command command, List<byte> data, int offset, out int length, out Response response)
        {
            response = default(Response);

            if(data.Count < offset + NameLengthSize)
            {
                length = default(int);
                response = Response.CommandFailed(command, $"Expected at least {offset + NameLengthSize} bytes of payload");
                return false;
            }

            length = BitConverter.ToInt32(data.GetRange(offset, NameLengthSize).ToArray(), 0);

            if(length <= 0)
            {
                response = Response.CommandFailed(command, "Provided length value is illegal");
                return false;
            }

            return true;
        }

        private static bool TryDecodeName(Command command, List<byte> data, int offset, int length, out string name, out Response response)
        {
            name = default(string);
            response = default(Response);

            if(data.Count != offset + length)
            {
                response = Response.CommandFailed(command, $"Expected {offset + length} bytes of payload");
                return false;
            }

            try
            {
                name = Encoding.UTF8.GetString(data.GetRange(offset, length).ToArray());
            }
            catch(Exception)
            {
                response = Response.CommandFailed(command, "Invalid name encoding");
                return false;
            }

            return true;
        }

        private const int PayloadOffset = InstanceIdOffset + InstanceIdSize;
        private const int InstanceIdOffset = 0;
        private const int InstanceIdSize = 4;
        private const int MachineIdOffset = InstanceIdSize;
        private const int MachineIdSize = 4;
        private const int NameOffset = MachineIdOffset + MachineIdSize;
        private const int NameLengthSize = 4;
    }

    public interface IInstanceBasedCommand<T> : ICommand
        where T : IEmulationElement
    {
        InstanceCollection<T> Instances { get; }

        Response Invoke(T instance, List<byte> data);
    }

    public class InstanceCollection<T>
    {
        public InstanceCollection()
        {
            collection = new Dictionary<int, T>();
        }

        public T this[int id] => collection[id];

        public bool TryAdd(T instance, out int id)
        {
            id = nextId;

            if(nextId < 0)
            {
                return false;
            }
            nextId += 1;

            collection.Add(id, instance);
            return true;
        }

        public void Remove(int id) => collection.Remove(id);

        public bool TryGet(int id, out T instance) => collection.TryGetValue(id, out instance);

        private int nextId;
        private readonly Dictionary<int, T> collection;
    }
}