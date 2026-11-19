//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Sensor;
using Antmicro.Renode.Utilities.RESD;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class SensorsData
    {
        public static WebSocketAPIResponse GetSensors(IMachine machine)
        {
            var peripherals = machine.GetRegisteredPeripherals();
            var data = peripherals
                .Select(entry => new { entry.Peripheral, Measurands = GetMeasurands(entry.Peripheral) })
                .Where(entry => entry.Measurands.Count > 0)
                .Select(entry => new SensorInfo
                {
                    Name = GPIOData.GetPeripheralFullName(entry.Peripheral, machine),
                    Measurands = entry.Measurands
                })
                .ToArray();

            return WebSocketAPIUtils.CreateActionResponse(data);
        }

        public static Dictionary<string, string[]> GetMeasurands(IPeripheral peripheral)
        {
            var sensorType = peripheral.GetType();
            var resdSampleSourceTypes = sensorType.FindInterfaces((type, _) => type.IsGenericType && type.GetGenericTypeDefinition() == typeof(IRESDSampleSource<>), null);

            var measurands = new Dictionary<string, string[]>();

            foreach(var resdSampleSourceType in resdSampleSourceTypes)
            {
                var resdSampleType = resdSampleSourceType.GetGenericArguments()[0];
                var measurand = MeasurandToRESDSample.FirstOrDefault(kv => kv.Value == resdSampleType).Key;
                if(measurand is null)
                {
                    continue;
                }

                var types = new List<string>();
                types.Add("raw");

                if(peripheral is IHasBounds)
                {
                    types.Add("percent");
                }

                if(peripheral is IHasNamedValues)
                {
                    types.Add("discrete");
                }
                measurands[measurand] = types.ToArray();
            }

            foreach(var (measurand, legacyInterface) in MeasurandExceptions)
            {
                if(!legacyInterface.IsAssignableFrom(sensorType))
                {
                    continue;
                }

                if(measurands.ContainsKey(measurand))
                {
                    continue;
                }

                // NOTE: Legacy sensors support only 'raw' type
                measurands[measurand] = ["raw"];
            }

            return measurands;
        }

        public static WebSocketAPIResponse GetSensorData(IPeripheral peripheral, string measurand, string type = null)
        {
            if(!TryGetSampleFromPeripheral(peripheral, measurand, out var sample))
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support '{measurand}' measurand");
            }

            switch(type)
            {
            case null: // NOTE: Default to 'raw'
            case "raw":
                return WebSocketAPIUtils.CreateActionResponse(new SensorSourceResponse { Value = sample, Type = "raw" });

            case "percent":
                if(peripheral is not IHasBounds)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support 'percent'");
                }

                var (lower, upper) = (peripheral as IHasBounds).Bounds;
                Func<long, long> mapValue = (value) => (value - (long)lower) * 100_000 / (long)(upper - lower);

                if(sample is Vector3 vectorSample)
                {
                    sample = vectorSample.Map((value, _) => mapValue(value));
                }
                else
                {
                    sample = mapValue((long)sample);
                }

                return WebSocketAPIUtils.CreateActionResponse(new SensorSourceResponse { Value = sample, Type = "percent" });

            case "discrete":
                if(peripheral is not IHasNamedValues)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support 'discrete'");
                }

                return WebSocketAPIUtils.CreateActionResponse(new SensorSourceResponse { Value = (peripheral as IHasNamedValues).ActiveNamedValue, Type = "discrete" });

            default:
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support '{type}'");
            }
        }

        public static WebSocketAPIResponse SetSensorData(IPeripheral peripheral, string measurand, string type, JToken data)
        {
            if(!TryGetSampleSetterForPeripheral(peripheral, measurand, out var setter, out var sourceType))
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support '{measurand}' measurand");
            }

            switch(type)
            {
            case null: // NOTE: Default to 'raw'
            case "raw":
                var newSample = ConstructRESDSample(sourceType, data);
                setter(newSample);
                break;

            case "percent":
                if(peripheral is not IHasBounds)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support 'percent'");
                }

                var (lower, upper) = (peripheral as IHasBounds).Bounds;
                Func<long, long> mapValue = (value) => (long)(upper - lower) * long.Clamp(value, 0, 100_000) / 100_000 + (long)lower;

                if(data.Type == JTokenType.Object && data.ToObject<Vector3>() is Vector3 vectorSample)
                {
                    vectorSample = vectorSample.Map((value, _) => mapValue(value));
                    setter(ConstructRESDSample(sourceType, JToken.FromObject(vectorSample)));
                }
                else
                {
                    var scalarSample = data.ToObject<long>();
                    scalarSample = mapValue(scalarSample);
                    setter(ConstructRESDSample(sourceType, JToken.FromObject(scalarSample)));
                }
                break;

            case "discrete":
                var peripheralWithNamedValues = peripheral as IHasNamedValues;
                if(peripheralWithNamedValues is null)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support 'discrete'");
                }

                var newNamedValue = data.ToObject<string>();
                if(!peripheralWithNamedValues.NamedValues.ContainsKey(newNamedValue))
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"'{newNamedValue}' is not a valid value for {peripheral.GetName()}");
                }

                peripheralWithNamedValues.ActiveNamedValue = newNamedValue;
                break;

            default:
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support '{type}'");
            }

            return WebSocketAPIUtils.CreateActionResponse("ok");
        }

        public static WebSocketAPIResponse SetSensorDataRelative(IPeripheral peripheral, string measurand, string type, JToken data)
        {
            if(peripheral is not IHasBounds)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support relative change");
            }

            if(!TryGetSampleSetterForPeripheral(peripheral, measurand, out var setter, out var sourceType) ||
               !TryGetSampleFromPeripheral(peripheral, measurand, out var sample))
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse($"{peripheral.GetName()} doesn't support '{measurand}' measurand");
            }

            var (min, max) = (peripheral as IHasBounds).Bounds;
            object convertedData;
            if(sample is Vector3)
            {
                convertedData = data.ToObject<Vector3>();
            }
            else
            {
                convertedData = data.ToObject<long>();
            }

            object returnObject;

            switch(type)
            {
            case null: // NOTE: Default to 'raw'
            case "raw":
                if(convertedData is Vector3)
                {
                    returnObject = (convertedData as Vector3).Add(sample as Vector3);
                }
                else
                {
                    returnObject = (long)convertedData + (long)sample;
                }

                break;

            case "percent":
                Func<long, long> mapValue = (value) => (long)Math.Floor((max - min) * value / 100_000m);
                if(convertedData is Vector3)
                {
                    convertedData = (convertedData as Vector3).Map((value, _) => mapValue(value));
                    returnObject = (convertedData as Vector3).Add(sample as Vector3);
                }
                else
                {
                    convertedData = mapValue((long)convertedData);
                    returnObject = (long)convertedData + (long)sample;
                }
                break;

            default:
                return WebSocketAPIUtils.CreateEmptyActionResponse("Invalid arguments");
            }
            ;

            if(returnObject is Vector3)
            {
                returnObject = (returnObject as Vector3).Map((value, _) => long.Clamp(value, min, max));
            }
            else
            {
                returnObject = long.Clamp((long)returnObject, min, max);
            }

            setter(ConstructRESDSample(sourceType, JToken.FromObject(returnObject)));

            return WebSocketAPIUtils.CreateActionResponse("ok");
        }

        private static bool TryGetSampleSetterForPeripheral(IPeripheral peripheral, string measurand, out Action<RESDSample> setter, out Type sourceType)
        {
            if(MeasurandToRESDSample.TryGetValue(measurand, out sourceType) &&
               peripheral.GetType().IsAssignableTo(typeof(IRESDSampleSource<>).MakeGenericType(new[] { sourceType })))
            {
                var resdType = typeof(IRESDSampleSource<>).MakeGenericType(new[] { sourceType });
                var invoker = resdType.GetMethod("TrySetSample");
                setter = (newSample) => invoker.Invoke(peripheral, [newSample]);
                return true;
            }
            else if(MeasurandExceptions.ContainsKey(measurand))
            {
                setter = (newSample) => LegacySensorDataSetter[measurand](peripheral, newSample);
                return true;
            }

            setter = null;
            return false;
        }

        private static bool TryGetSampleFromPeripheral(IPeripheral peripheral, string measurand, out object sample)
        {
            if(MeasurandToRESDSample.TryGetValue(measurand, out var sourceType) &&
                peripheral.GetType().IsAssignableTo(typeof(IRESDSampleSource<>).MakeGenericType(new[] { sourceType })))
            {
                sample = RESDSampleGetter(measurand, peripheral);
                return true;
            }
            else if(MeasurandExceptions.ContainsKey(measurand))
            {
                sample = LegacySensorDataGetter[measurand](peripheral);
                return true;
            }

            sample = null;
            return false;
        }

        private static RESDSample ConstructRESDSample(Type resdType, JToken sample)
        {
            switch(resdType)
            {
            case Type type when type == typeof(TemperatureSample):
                var temperature = sample.ToObject<int>();
                return new TemperatureSample(temperature);

            case Type type when type == typeof(AccelerationSample):
                var acceleration = sample.ToObject<Vector3>();
                return new AccelerationSample((int)acceleration.X, (int)acceleration.Y, (int)acceleration.Z);

            case Type type when type == typeof(AngularRateSample):
                var angularRate = sample.ToObject<Vector3>();
                return new AngularRateSample((int)angularRate.X, (int)angularRate.Y, (int)angularRate.Z);

            case Type type when type == typeof(VoltageSample):
                var voltage = sample.ToObject<uint>();
                return new VoltageSample(voltage);

            case Type type when type == typeof(ECGSample):
                var ecg = sample.ToObject<int>();
                return new ECGSample(ecg);

            case Type type when type == typeof(HumiditySample):
                var humidity = sample.ToObject<uint>();
                return new HumiditySample(humidity);

            case Type type when type == typeof(PressureSample):
                var pressure = sample.ToObject<ulong>();
                return new PressureSample(pressure);

            case Type type when type == typeof(MagneticSample):
                var magneticFluxDensity = sample.ToObject<Vector3>();
                return new MagneticSample((int)magneticFluxDensity.X, (int)magneticFluxDensity.Y, (int)magneticFluxDensity.Z);

            case Type type when type == typeof(IlluminanceSample):
                var illuminance = sample.ToObject<uint>();
                return new IlluminanceSample(illuminance);

            default:
                throw new UnreachableException();
            }
            ;
        }

        private static T GetRESDSampleFromSource<T>(object source)
            where T : RESDSample
        {
            return (source as IRESDSampleSource<T>).Sample;
        }

        private static object RESDSampleGetter(string type, object source)
        {
            switch(type)
            {
            case "temperature":
                return (long)GetRESDSampleFromSource<TemperatureSample>(source).Temperature;
            case "acceleration":
                var acceleration = GetRESDSampleFromSource<AccelerationSample>(source);
                return new Vector3 { X = acceleration.AccelerationX, Y = acceleration.AccelerationY, Z = acceleration.AccelerationZ };
            case "angular-rate":
                var angularRate = GetRESDSampleFromSource<AngularRateSample>(source);
                return new Vector3 { X = angularRate.AngularRateX, Y = angularRate.AngularRateY, Z = angularRate.AngularRateZ };
            case "voltage":
                return (long)GetRESDSampleFromSource<VoltageSample>(source).Voltage;
            case "ecg":
                return (long)GetRESDSampleFromSource<ECGSample>(source).ECG;
            case "humidity":
                return (long)GetRESDSampleFromSource<HumiditySample>(source).Humidity;
            case "pressure":
                return (long)GetRESDSampleFromSource<PressureSample>(source).Pressure;
            case "magnetic-flux-density":
                var magneticFlux = GetRESDSampleFromSource<MagneticSample>(source);
                return new Vector3 { X = magneticFlux.MagneticFluxDensityX, Y = magneticFlux.MagneticFluxDensityY, Z = magneticFlux.MagneticFluxDensityZ };
            case "illuminance":
                return (long)GetRESDSampleFromSource<IlluminanceSample>(source).Illuminance;
            default:
                throw new UnreachableException();
            }
        }

        private static readonly Dictionary<string, Type> MeasurandToRESDSample = new Dictionary<string, Type>
        {
            { "temperature",           typeof(TemperatureSample) },
            { "acceleration",          typeof(AccelerationSample) },
            { "angular-rate",          typeof(AngularRateSample) },
            { "voltage",               typeof(VoltageSample) },
            { "ecg",                   typeof(ECGSample) },
            { "humidity",              typeof(HumiditySample) },
            { "pressure",              typeof(PressureSample) },
            { "magnetic-flux-density", typeof(MagneticSample) },
            { "illuminance",           typeof(IlluminanceSample) }
        };

        private static readonly Dictionary<string, Type> MeasurandExceptions = new Dictionary<string, Type>
        {
            { "temperature",           typeof(ITemperatureSensor) },
            { "humidity",              typeof(IHumiditySensor) },
            { "magnetic-flux-density", typeof(IMagneticSensor) },
            { "illuminance",           typeof(IIlluminanceSensor) }
        };

        private static readonly Dictionary<string, Func<IPeripheral,  object>> LegacySensorDataGetter = new Dictionary<string, Func<IPeripheral, object>>
        {
            { "temperature", (sensor) => Convert.ToInt32(Decimal.ToDouble((sensor as ITemperatureSensor).Temperature) * 1e3) },
            { "humidity", (sensor) => Convert.ToInt32(Decimal.ToDouble((sensor as IHumiditySensor).Humidity) * 1e3) },
            { "magnetic-flux-density", (sensor) => GetMagneticSensorData(sensor as IMagneticSensor) },
            { "illuminance", (sensor) => Convert.ToInt32(Decimal.ToDouble((sensor as IIlluminanceSensor).Illuminance) * 1e3) }
        };

        private static readonly Dictionary<string, Action<IPeripheral, RESDSample>> LegacySensorDataSetter = new Dictionary<string, Action<IPeripheral, RESDSample>>
        {
            { "temperature", (sensor, sample) => (sensor as ITemperatureSensor).Temperature = (sample as TemperatureSample).Temperature / 1e3m },
            { "humidity", (sensor, sample) => (sensor as IHumiditySensor).Humidity = (sample as HumiditySample).Humidity / 1e3m },
            { "magnetic-flux-density", (sensor, sample) => SetMagneticSensorData(sensor as IMagneticSensor, sample as MagneticSample) },
            { "illuminance", (sensor, sample) => (sensor as IIlluminanceSensor).Illuminance = (sample as IlluminanceSample).Illuminance / 1e3m }
        };

        private static void SetMagneticSensorData(IMagneticSensor sensor, MagneticSample sample)
        {
            sensor.MagneticFluxDensityX = sample.MagneticFluxDensityX;
            sensor.MagneticFluxDensityY = sample.MagneticFluxDensityY;
            sensor.MagneticFluxDensityZ = sample.MagneticFluxDensityZ;
        }

        private static object GetMagneticSensorData(IMagneticSensor magneticSensor)
        {
            return new Vector3
            {
                X = magneticSensor.MagneticFluxDensityX,
                Y = magneticSensor.MagneticFluxDensityY,
                Z = magneticSensor.MagneticFluxDensityZ
            };
        }

        private class SensorInfo
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("measurands")]
            public Dictionary<string, string[]> Measurands;
        }

        private class SensorSourceResponse
        {
            [JsonProperty(propertyName: "type")]
            public string Type;

            [JsonProperty(propertyName: "value")]
            public object Value;
        }

        private class Vector3
        {
            public Vector3 Map(Func<long, int, long> f)
            {
                return new Vector3
                {
                    X = f(X, 0),
                    Y = f(Y, 1),
                    Z = f(Z, 2),
                };
            }

            public Vector3 Add(Vector3 other)
            {
                return new Vector3
                {
                    X = X + other.X,
                    Y = Y + other.Y,
                    Z = Z + other.Z,
                };
            }

            [JsonProperty("x")]
            public long X;
            [JsonProperty("y")]
            public long Y;
            [JsonProperty("z")]
            public long Z;
        }
    }
}
