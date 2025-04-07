//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Miscellaneous;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class GPIOData
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

        public static WebSocketAPIResponse ButtonSet(IMachine _, IPeripheral peripheral, bool value)
        {
            var button = peripheral as Button;

            if(value && button.Pressed)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("trying to press button which is already pressed");
            }
            else if(!value && !button.Pressed)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("trying to release button which is not pressed");
            }

            if(value)
            {
                button.Press();
            }
            else
            {
                button.Release();
            }

            return WebSocketAPIUtils.CreateActionResponse("ok");
        }
    }
}