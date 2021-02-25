//
// Copyright (c) 2010-2021 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols
{
    // ActionType must be in sync with the Verilator integration library
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
        PushData,
        GetData = 12 //all custom action type numbers must not fall in this range
    }
}
