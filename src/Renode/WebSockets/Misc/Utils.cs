//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CAN;
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.Peripherals.Sensor;
using Antmicro.Renode.Peripherals.SPI;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Peripherals.Video;

using Newtonsoft.Json;

using InterestingPeripheralType = Antmicro.Renode.WebSockets.Providers.EmulationInfoProvider.InterestingPeripheralType;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class Utils
    {
        public static InterestingPeripheralType[] GetInterestingTypes(IPeripheral peripheral)
        {
            var peripheralType = peripheral.GetType();
            return peripheralTypeMap.Where(e => e.type.IsAssignableFrom(peripheralType)).Select(e => e.tag).ToArray();
        }

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

        public static WebSocketAPIResponse GetPeripheralsWithTypes(IMachine machine)
        {
            var peripheralsInfo = machine.GetPeripheralsOfType<IPeripheral>().Select(p =>
            {
                var types = GetInterestingTypes(p);
                if(types.Length == 0)
                {
                    return null;
                }
                return new PeripheralInfo
                {
                    Name = GetPeripheralFullName(p, machine),
                    Types = types,
                };
            }).Where(i => i is not null).ToArray();

            return WebSocketAPIUtils.CreateActionResponse(peripheralsInfo);
        }

        private static readonly List<(Type type, InterestingPeripheralType tag)> peripheralTypeMap = new()
        {
            (typeof(ISensor), InterestingPeripheralType.Sensor),
            (typeof(IUART), InterestingPeripheralType.UART),
            (typeof(ISPIController), InterestingPeripheralType.SPI),
            (typeof(ICAN), InterestingPeripheralType.CAN),
            (typeof(IVideo), InterestingPeripheralType.Video),
            (typeof(ILed), InterestingPeripheralType.LED),
            (typeof(Button), InterestingPeripheralType.Button)
        };

        private class PeripheralInfo
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("types")]
            public InterestingPeripheralType[] Types;
        }
    }
}
