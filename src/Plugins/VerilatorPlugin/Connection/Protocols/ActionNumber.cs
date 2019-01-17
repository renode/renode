//
// Copyright (c) 2010-2019 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.Plugins.VerilatorPlugin.Connection.Protocols
{
    public enum ActionNumber
    {
        TickClock,
        WriteToBus,
        ReadFromBus,
        ResetPeripheral,
        LogMessage,
        Interrupt,
        Disconnect,
    }
}
