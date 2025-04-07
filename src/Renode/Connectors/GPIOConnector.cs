//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Time;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Connectors
{
    public static class GPIOConnectorExtensions
    {
        public static void CreateGPIOConnector(this Emulation emulation, string name)
        {
            emulation.ExternalsManager.AddExternal(new GPIOConnector(), name);
        }
    }

    public class GPIOConnector : IExternal, IConnectable<IPeripheral>, IGPIOReceiver
    {
        public GPIOConnector()
        {
            connectorPin = new GPIO();
        }

        public void AttachTo(IPeripheral peripheral)
        {
            if(peripherals.Count == 2)
            {
                throw new RecoverableException("Only two peripherals can be connected to this GPIO Connector (source and destination).");
            }
            peripherals.Add(peripheral);
        }

        public void OnGPIO(int number, bool value)
        {
            if(!TimeDomainsManager.Instance.TryGetVirtualTimeStamp(out var vts))
            {
                vts = new TimeStamp(default(TimeInterval), EmulationManager.ExternalWorld);
            }

            var endpoints = connectorPin.Endpoints;
            for(var i = 0; i < endpoints.Count; i++)
            {
                endpoints[i].Receiver.GetMachine().HandleTimeDomainEvent(connectorPin.Set, value, vts);
            }
        }

        //This method should not be executed on a runnning emulation, as IGPIO.Connect call
        //may lead to nondeterminism.
        public void SelectSourcePin(INumberedGPIOOutput source, int pinNumber)
        {
            VerifyPeripheralOrThrow(source);
            if(!source.Connections.TryGetValue(pinNumber, out IGPIO tempPin))
            {
                throw new RecoverableException("Peripheral {0} has no GPIO with number: {1}".FormatWith(source, pinNumber));
            }
            if(sourcePin != null)
            {
                sourcePin.Disconnect();
            }
            sourcePin = tempPin ?? throw new RecoverableException("Source PIN cannot be selected.");
            sourcePin.Connect(this, 0);
        }

        //This method should not be executed on a runnning emulation, as IGPIO.Connect call
        //may lead to nondeterminism.
        public void SelectDestinationPin(IGPIOReceiver receiver, int pinNumber)
        {
            VerifyPeripheralOrThrow(receiver);
            if(connectorPin.IsConnected)
            {
                this.Log(LogLevel.Warning, "Overwriting destination PIN connection.");
                destinationMachine.MachineReset -= ResetDestinationPinState;
            }
            GetDestinationMachineAndAttachToEvent(receiver);
            connectorPin.Connect(receiver, pinNumber);
        }

        public void DetachFrom(IPeripheral peripheral)
        {
            if(connectorPin.IsConnected && connectorPin.Endpoints.Any(x => x.Receiver == peripheral))
            {
                connectorPin.Disconnect(connectorPin.Endpoints.First(x => x.Receiver == peripheral));
                destinationMachine.MachineReset -= ResetDestinationPinState;
            }
            else
            {
                if(sourcePin != null)
                {
                    sourcePin.Disconnect();
                }
            }
            peripherals.Remove(peripheral);
        }

        public void Reset()
        {
            if(sourcePin == null)
            {
                connectorPin.Set(false);
            }
            else
            {
                connectorPin.Set(sourcePin.IsSet);
            }
        }

        private void VerifyPeripheralOrThrow(IPeripheral peripheral)
        {
            var attachedPeripheral = peripherals.FirstOrDefault(p => p == peripheral);
            if(attachedPeripheral == null)
            {
                throw new RecoverableException("Peripheral {0} is not connected to the GPIO Connector.".FormatWith(peripheral));
            }
        }

        private void GetDestinationMachineAndAttachToEvent(IPeripheral receiver)
        {
            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineForPeripheral(receiver, out destinationMachine))
            {
                throw new RecoverableException("Could not resolve machine for designated peripheral.");
            }
            destinationMachine.MachineReset += ResetDestinationPinState;
        }

        private void ResetDestinationPinState(IMachine machine)
        {
            Reset();
        }

        private IMachine destinationMachine;
        private IGPIO sourcePin;
        private readonly ISet<IPeripheral> peripherals = new HashSet<IPeripheral>();

        private readonly IGPIO connectorPin;
    }
}