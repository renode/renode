//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Migrant;
using Antmicro.Migrant.Hooks;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Sensor;
using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.EmulationEnvironment
{
    public static class EmulationEnvironmentExtensions
    {
        public static void CreateEnvironment(this Emulation emulation, string environmentName)
        {
            emulation.ExternalsManager.AddExternal(new EmulationEnvironment(), environmentName);
        }

        public static void SetEnvironment(this Machine machine, EmulationEnvironment targetEnvironment)
        {
            targetEnvironment.AddToEnvironment(machine);
        }

        public static void SetEnvironment(this ISensor sensor, EmulationEnvironment targetEnvironment)
        {
            targetEnvironment.AddToEnvironment(sensor);
        }
    }

    public class EmulationEnvironment : IExternal
    {
        public EmulationEnvironment()
        {
            registeredMachines = new HashSet<IMachine>();
            registeredSensors = new HashSet<ISensor>();
            InitSensorDelegates();
        }

        [HideInMonitor]
        public void AddToEnvironment(IMachine machine)
        {
            var environments = EmulationManager.Instance.CurrentEmulation.ExternalsManager.GetExternalsOfType<EmulationEnvironment>().ToList();
            RemoveMachineFromOtherEnvironments(environments, machine);
            foreach(var sensor in machine.GetPeripheralsOfType<ISensor>())
            {
                RemoveSensorFromOtherEnvironments(environments, sensor);
                AddSensorAndUpdate(sensor);
            }
            ObserveChangesInMachinePeripherals(machine);
            ObserveMachineReset(machine);
            ObserveMachineRemoval();
            registeredMachines.Add(machine);
        }

        [HideInMonitor]
        public void AddToEnvironment(ISensor sensor)
        {
            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineForPeripheral(sensor, out var machine))
            {
                throw new RecoverableException($"Could not resolve machine for peripheral {sensor}.");
            }
            ObserveChangesInMachinePeripherals(machine);
            ObserveMachineReset(machine);

            RemoveSensorFromOtherEnvironments(EmulationManager.Instance.CurrentEmulation.ExternalsManager.GetExternalsOfType<EmulationEnvironment>(), sensor);
            AddSensorAndUpdate(sensor);
        }

        public IEnumerable<string> GetRegisteredSensorsNames()
        {
            return GetNamesOfElements(registeredSensors.Cast<IEmulationElement>().ToList());
        }

        public IEnumerable<string> GetRegisteredMachineNames()
        {
            return GetNamesOfElements(registeredMachines.Cast<IEmulationElement>().ToList());
        }

        public decimal Temperature
        {
            get
            {
                return sensorValueAndUpdateDelegates[typeof(ITemperatureSensor)].Value;
            }

            set
            {
                sensorValueAndUpdateDelegates[typeof(ITemperatureSensor)].Value = value;
                UpdateSensorsOfType<ITemperatureSensor>(value);
            }
        }

        public decimal Humidity
        {
            get
            {
                return sensorValueAndUpdateDelegates[typeof(IHumiditySensor)].Value;
            }

            set
            {
                sensorValueAndUpdateDelegates[typeof(IHumiditySensor)].Value = value;
                UpdateSensorsOfType<IHumiditySensor>(value);
            }
        }

        [PostDeserialization]
        private void InitSensorDelegates()
        {
            sensorValueAndUpdateDelegates = new Dictionary<Type, SensorValueAndUpdateDelegate>()
            {
                { typeof(ITemperatureSensor), new SensorValueAndUpdateDelegate() { Setter = (ISensor sensor, decimal value) => ((ITemperatureSensor)sensor).Temperature = value } },
                { typeof(IHumiditySensor), new SensorValueAndUpdateDelegate() { Setter = (ISensor sensor, decimal value) => ((IHumiditySensor)sensor).Humidity = value } }
            };
        }

        private IEnumerable<string> GetNamesOfElements(List<IEmulationElement> elements)
        {
            var names = new List<string>();
            foreach(var element in elements)
            {
                if(!EmulationManager.Instance.CurrentEmulation.TryGetEmulationElementName(element, out string name))
                {
                    this.Log(LogLevel.Error, $"Trying to get name for an object of type {element.GetType().Name}, but it is not registered.");
                }
                names.Add(name);
            }
            return names;
        }

        private void RemoveMachineFromOtherEnvironments(IEnumerable<EmulationEnvironment> environments, IMachine machine)
        {
            foreach(var environment in environments.Where(env => env != this && env.registeredMachines.Contains(machine)))
            {
                environment.StopObservingChangesInMachinePeripherals(machine);
                environment.StopObservingMachineReset(machine);
                environment.StopObservingMachineRemoval();
                environment.registeredMachines.Remove(machine);
            }
        }

        private void RemoveSensorFromOtherEnvironments(IEnumerable<EmulationEnvironment> environments, ISensor sensor)
        {
            foreach(var environment in environments.Where(env => env != this && env.registeredSensors.Contains(sensor)))
            {
                environment.registeredSensors.Remove(sensor);
            }
        }

        private void AddSensorAndUpdate(ISensor sensor)
        {
            if(registeredSensors.Add(sensor))
            {
                SetSensorValues(sensor);
            }
        }

        private void ObserveChangesInMachinePeripherals(IMachine machine)
        {
            machine.PeripheralsChanged += MachinePeripheralsChanged;
        }

        private void StopObservingChangesInMachinePeripherals(IMachine machine)
        {
            machine.PeripheralsChanged -= MachinePeripheralsChanged;
        }

        private void ObserveMachineReset(IMachine machine)
        {
            machine.MachineReset += OnMachineReset;
        }

        private void StopObservingMachineReset(IMachine machine)
        {
            machine.MachineReset -= OnMachineReset;
        }

        private void ObserveMachineRemoval()
        {
            EmulationManager.Instance.CurrentEmulation.MachineRemoved += OnMachineRemoval;
        }

        private void StopObservingMachineRemoval()
        {
            EmulationManager.Instance.CurrentEmulation.MachineRemoved -= OnMachineRemoval;
        }

        private void MachinePeripheralsChanged(IMachine machine, PeripheralsChangedEventArgs e)
        {
            if(e.Peripheral is ISensor sensor)
            {
                if(e.Operation == PeripheralsChangedEventArgs.PeripheralChangeType.Addition)
                {
                    AddSensorAndUpdate(sensor);
                }
                else if(e.Operation == PeripheralsChangedEventArgs.PeripheralChangeType.CompleteRemoval)
                {
                    registeredSensors.Remove(sensor);
                }
            }
        }

        private void OnMachineReset(IMachine machine)
        {
            foreach(var sensor in machine.GetPeripheralsOfType<ISensor>().Where(s => registeredSensors.Contains(s)))
            {
                SetSensorValues(sensor);
            }
        }

        private void OnMachineRemoval(IMachine machine)
        {
            registeredMachines.Remove(machine);
        }

        private void UpdateSensorsOfType<T>(decimal value) where T : ISensor
        {
            var sensorValueAndUpdateDelegate = sensorValueAndUpdateDelegates[typeof(T)];
            foreach(var sensor in registeredSensors.OfType<T>())
            {
                sensorValueAndUpdateDelegate.Setter(sensor, value);
            }
        }

        private void SetSensorValues(ISensor sensor)
        {
            var sensorType = sensor.GetType();
            foreach(var item in sensorValueAndUpdateDelegates.Where(i => i.Key.IsAssignableFrom(sensorType)))
            {
                sensorValueAndUpdateDelegates[item.Key].Setter(sensor, item.Value.Value);
            }
        }

        [Transient]
        private IDictionary<Type, SensorValueAndUpdateDelegate> sensorValueAndUpdateDelegates;

        private readonly ISet<IMachine> registeredMachines;
        private readonly ISet<ISensor> registeredSensors;

        private class SensorValueAndUpdateDelegate
        {
            public Action<ISensor, decimal> Setter;
            public decimal Value;
        }
    }
}