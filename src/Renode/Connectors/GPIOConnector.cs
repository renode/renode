//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;
using Antmicro.Renode.Time;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using System.Collections.Generic;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Peripherals;

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
            peripherals.Add(peripheral);
        }

        public void OnGPIO(int number, bool value)
        {
            var mach = connectorPin.Endpoint.Receiver.GetMachine();
            mach.HandleTimeDomainEvent(connectorPin.Set, value, TimeDomainsManager.Instance.VirtualTimeStamp);
        }

        //This method should not be executed on a runnning emulation, as IGPIO.Connect call
        //may lead to nondeterminism.
        public void SelectSourcePin(INumberedGPIOOutput source, int pinNumber)
        {
            VerifyPeripheralOrThrow(source);
            IGPIO tempPin;
            if(!source.Connections.TryGetValue(pinNumber, out tempPin))
            {
                throw new RecoverableException("Peripheral {0} has no GPIO with number: {1}".FormatWith(source, pinNumber));
            }
            if(tempPin == null)
            {
                throw new RecoverableException("Source PIN cannot be selected.");
            }
            if(sourcePin != null)
            {
                sourcePin.Disconnect();
            }
            sourcePin = tempPin;
            if(sourcePin.IsConnected)
            {
                this.Log(LogLevel.Warning, "Overwriting source PIN connection.");
            }
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
            if(connectorPin.IsConnected && peripheral == connectorPin.Endpoint.Receiver)
            {
                connectorPin.Disconnect();
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

        private void ResetDestinationPinState(Machine machine)
        {
            Reset();
        }

        private readonly IGPIO connectorPin;

        private Machine destinationMachine;
        private IGPIO sourcePin;
        private IList<IPeripheral> peripherals = new List<IPeripheral>();
    }
}
