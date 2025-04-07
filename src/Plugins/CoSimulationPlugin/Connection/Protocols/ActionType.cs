//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Plugins.CoSimulationPlugin.Connection.Protocols
{
    // ActionType must be in sync with the cosimulation library.
    // Append new actions to the end to preserve compatibility.
    public enum ActionType
    {
        InvalidAction = 0,
        TickClock,
        WriteToBus, //obsolete
        ReadFromBus, //obsolete
        ResetPeripheral,
        LogMessage,
        Interrupt,
        Disconnect,
        Error,
        OK,
        Handshake,
        PushDoubleWord,
        GetDoubleWord,
        PushWord,
        GetWord,
        PushByte,
        GetByte,
        IsHalted,
        RegisterGet,
        RegisterSet,
        SingleStepMode,
        ReadFromBusByte,
        ReadFromBusWord,
        ReadFromBusDoubleWord,
        ReadFromBusQuadWord,
        WriteToBusByte,
        WriteToBusWord,
        WriteToBusDoubleWord,
        WriteToBusQuadWord,
        PushQuadWord,
        GetQuadWord,
        PushConfirmation,
        Step = 100, //all custom action type numbers must not fall in this range
    }
}