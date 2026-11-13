//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Time;
using Antmicro.Renode.UserInterface;

#nullable enable

namespace Antmicro.Renode.Network.ExternalControl;

public class EmulationCommand(ExternalControlEndpoint parent) : BaseCommand(parent)
{
    public override MessagePayload Invoke(MessagePayload payload)
    {
        var emulation = EmulationManager.Instance.CurrentEmulation;
        switch(payload.Data)
        {
        case [(byte)Operation.Start]:
            if(!emulation.IsStarted)
            {
                emulation.StartAll();
            }
            return MessagePayload.Success(Identifier);

        case [(byte)Operation.Pause]:
            emulation.PauseAll();
            return MessagePayload.Success(Identifier);

        case [(byte)Operation.SetQuantum, .. var quantum] when quantum.Length == sizeof(ulong):
            emulation.SetGlobalQuantum(TimeInterval.FromNanoseconds(BitConverter.ToUInt64(quantum)));
            return MessagePayload.Success(Identifier);

        case [(byte)Operation.RunScript, .. var path]:
            return RunScript(path);

        default:
            return MessagePayload.Error(Identifier, "Unexpected command format");
        }
    }

    public override Command Identifier => Command.Emulation;

    private MessagePayload RunScript(byte[] encodedPath)
    {
        string path;
        try
        {
            path = Encoding.UTF8.GetString(encodedPath);
        }
        catch(ArgumentException)
        {
            return MessagePayload.Error(Identifier, "Invalid script path encoding");
        }
        return InteractWithMonitor((monitor, interaction) => monitor.TryExecuteScript(path, interaction));
    }

    private enum Operation : byte
    {
        Start = 0,
        Pause,
        SetQuantum,
        RunScript,
    }
}
