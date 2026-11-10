//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CPU;

#nullable enable

namespace Antmicro.Renode.Network.ExternalControl;

public class CPUCommand(ExternalControlEndpoint parent) : BaseCommand(parent), IInstanceBasedCommand<ICPU>
{
    public override MessagePayload Invoke(MessagePayload payload) => this.InvokeHandledWithInstance(payload);

    public MessagePayload Invoke(ICPU cpu, ReadOnlySpan<byte> data)
    {
        switch(data)
        {
        case [(byte)Operation.GetPC]:
            return MessagePayload.Success(Identifier, BitConverter.GetBytes(cpu.PC.RawValue));

        case [(byte)Operation.SetPC, .. var pc] when pc.Length == sizeof(ulong):
            return SetPC(cpu, BitConverter.ToUInt64(pc));

        case [(byte)Operation.IsHalted]:
            return MessagePayload.Success(Identifier, BitConverter.GetBytes(cpu.IsHalted));

        case [(byte)Operation.SetHalted, var halted]:
            cpu.IsHalted = halted != 0;
            return MessagePayload.Success(Identifier);

        default:
            return MessagePayload.Error(Identifier, "Unexpected command format");
        }
    }

    public InstanceCollection<ICPU> Instances { get; } = new();

    public override Command Identifier => Command.CPU;

    private MessagePayload SetPC(ICPU cpu, ulong pc)
    {
        var bits = (int)cpu.PC.Bits;
        if(bits < 64 && pc >> bits != 0)
        {
            return MessagePayload.Error(Identifier, $"The {bits}-bit PC can't hold 0x{pc:X}");
        }

        var machine = cpu.GetMachine();
        if(machine.IsPaused)
        {
            cpu.PC = pc;
        }
        else
        {
            // Sets the PC at the next synchronization point, because a running CPU can overwrite it.
            machine.LocalTimeSource.ExecuteInNearestSyncedState(_ => cpu.PC = pc);
        }
        return MessagePayload.Success(Identifier);
    }

    private enum Operation : byte
    {
        GetPC = 0,
        SetPC,
        IsHalted,
        SetHalted,
    }
}
