//
// Copyright (c) 2010-2022 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols
{
    // ActionType must be in sync with the Verilator integration library.
    // Append new actions to the end to preserve compatibility.
    public enum ActionType
    {
        InvalidAction = 0,
        TickClock,
        WriteToBus,
        ReadFromBus,
        ResetPeripheral,
        LogMessage,
        Interrupt,
        Disconnect,
        Error,
        OK,
        Handshake,
        PushDoubleWord,
        GetDoubleWord,
    }
}
