//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Sensor;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class SensorsData
    {
        public static WebSocketAPIResponse GetSensors(IMachine machine)
        {
            var peripherals = machine.GetPeripheralsOfType<ISensor>();
            var data = peripherals.Select(p => new SensorInfo
            {
                Name = GPIOData.GetPeripheralFullName(p, machine),
                Types = GetSensorTypes(p)
            }).ToArray();

            return WebSocketAPIUtils.CreateActionResponse(data);
        }

        public static WebSocketAPIResponse GetSensorData(IPeripheral peripheral, string type)
        {
            var sensorData = SensorDataGetter[type](peripheral as ISensor);
            return WebSocketAPIUtils.CreateActionResponse(sensorData);
        }

        public static WebSocketAPIResponse SetSensorData(IPeripheral peripheral, string type, JToken value)
        {
            SensorDataSetter[type](peripheral as ISensor, value);
            return WebSocketAPIUtils.CreateActionResponse("ok");
        }

        private static readonly Dictionary<string, Type> SensorType = new Dictionary<string, Type>
        {
            { "temperature", typeof(ITemperatureSensor) },
            { "voltage", typeof(IADC) },
            { "humidity", typeof(IHumiditySensor) },
            { "magnetic-flux-density", typeof(IMagneticSensor) }
        };

        private static readonly Dictionary<string, Func<ISensor, object>> SensorDataGetter = new Dictionary<string, Func<ISensor, object>>
        {
            { "temperature", (sensor) => Convert.ToInt32(Decimal.ToDouble((sensor as ITemperatureSensor).Temperature) * 1e3) },
            { "voltage", (sensor) => (sensor as IADC).GetADCValue(0) },
            { "humidity", (sensor) => Convert.ToInt32(Decimal.ToDouble((sensor as IHumiditySensor).Humidity) * 1e3) },
            { "magnetic-flux-density", (sensor) => GetMagneticSensorData(sensor as IMagneticSensor) }
        };

        private static readonly Dictionary<string, Action<ISensor, JToken>> SensorDataSetter = new Dictionary<string, Action<ISensor, JToken>>
        {
            { "temperature", (sensor, data) =>  SetTemperature(sensor as ITemperatureSensor, data.ToObject<int>()) },
            { "voltage", (sensor, data) => SetVoltage(sensor as IADC, data.ToObject<uint>()) },
            { "humidity", (sensor, data) => SetHumidity(sensor as IHumiditySensor, data.ToObject<int>()) },
            { "magnetic-flux-density", (sensor, data) => SetMagneticSensorData(sensor as IMagneticSensor, data.ToObject<MagneticSensorData>()) }
        };

        private static MagneticSensorData GetMagneticSensorData(IMagneticSensor magneticSensor)
        {
            return new MagneticSensorData
            {
                X = magneticSensor.MagneticFluxDensityX,
                Y = magneticSensor.MagneticFluxDensityY,
                Z = magneticSensor.MagneticFluxDensityZ
            };
        }

        private static void SetTemperature(ITemperatureSensor sensor, int value)
        {
            sensor.Temperature = Convert.ToDecimal(value) / 1e3M;
        }

        private static void SetVoltage(IADC sensor, uint value)
        {
            sensor.SetADCValue(0, value);
        }

        private static void SetHumidity(IHumiditySensor sensor, int value)
        {
            sensor.Humidity = Convert.ToDecimal(value) / 1e3M;
        }

        private static void SetMagneticSensorData(IMagneticSensor sensor, MagneticSensorData data)
        {
            sensor.MagneticFluxDensityX = data.X;
            sensor.MagneticFluxDensityY = data.Y;
            sensor.MagneticFluxDensityZ = data.Z;
        }

        private static string[] GetSensorTypes(ISensor sensor)
        {
            var sensorType = sensor.GetType();
            return SensorType.Where(s => s.Value.IsAssignableFrom(sensorType)).Select(s => s.Key).ToArray();
        }

        private class SensorInfo
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("types")]
            public string[] Types;
        }

        private class MagneticSensorData
        {
            [JsonProperty("x")]
            public int X;
            [JsonProperty("y")]
            public int Y;
            [JsonProperty("z")]
            public int Z;
        }
    }
}