//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class Utils
    {
        public static string GetPeripheralFullName(IPeripheral peripheral, IMachine peripheralMachine = null)
        {
            var result = new StringBuilder();
            var machine = peripheralMachine ?? peripheral.GetMachine();

            if(!machine.TryGetLocalName(peripheral, out var peripheralLocalName))
            {
                return string.Empty;
            }

            result.Append(peripheralLocalName);

            var currentParent = machine.GetParentPeripherals(peripheral).FirstOrDefault();

            while(currentParent != null)
            {
                if(!machine.TryGetLocalName(currentParent, out var parentLocalName))
                {
                    return string.Empty;
                }

                result.Insert(0, '.');
                result.Insert(0, parentLocalName);

                currentParent = machine.GetParentPeripherals(currentParent).FirstOrDefault();
            }

            return result.ToString();
        }

        public static WebSocketAPIResponse GetPeripheralsNameOfType<T>(IMachine machine) where T : IPeripheral
        {
            var peripherals = machine.GetPeripheralsOfType<T>();
            var peripheralsNames = peripherals.Select(p => GetPeripheralFullName(p, machine)).ToArray();

            return WebSocketAPIUtils.CreateActionResponse(peripheralsNames);
        }
    }
}
