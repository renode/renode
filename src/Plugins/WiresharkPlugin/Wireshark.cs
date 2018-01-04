//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Collections.Generic;
using Antmicro.Renode.Peripherals.Wireless;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Network;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Tools.Network;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public class Wireshark : IHostMachineElement, IExternal
    {
        public Wireshark(string sinkName, LinkLayer layer, string wiresharkPath)
        {
            currentEmulation = EmulationManager.Instance.CurrentEmulation;
            EmulationManager.Instance.EmulationChanged += ClearLog;
            currentEmulation.MachineRemoved += OnMachineRemoved;
            wiresharkSinkName = sinkName;
            wiresharkSender = new WiresharkSender(wiresharkSinkName, (uint)layer, wiresharkPath);
            this.layer = layer;
        }

        public void LogToWireshark(INetworkLog<INetworkInterface> reporter)
        {
            lock(innerLock)
            {
                if(IsConfiguredForMediumType(reporter))
                {
                    AddMedium(reporter);
                }
            }
        }

        public void LogToWireshark(INetworkLog<INetworkInterface> reporter, INetworkInterface iface)
        {
            lock(innerLock)
            {
                if(IsConfiguredForMediumType(reporter))
                {
                    AddInterface(reporter, iface);
                }
            }
        }

        public void DetachFrom(INetworkLog<INetworkInterface> reporter)
        {
            DetachMedium(reporter);
        }

        public void DetachFrom(INetworkInterface iface)
        {
            DetachInterface(iface);
        }

        public void Run()
        {
            lock(innerLock)
            {
                if(!wiresharkSender.TryOpenWireshark())
                {
                    throw new RecoverableException("Wireshark is already running.");
                }
            }
        }

        private bool IsConfiguredForMediumType(INetworkLog<INetworkInterface> medium)
        {
            var typeOfInterface = medium.GetType();

            lock(innerLock)
            {
                if(mediumToLinkLayer[typeOfInterface] == layer)
                {
                    return true;
                }

            }
            if(layer == LinkLayer.Wireless_802_15_4)
            {
                throw new RecoverableException("Cannot log ethernet traffic to wireless-configured Wireshark.");
            }
            else
            {
                throw new RecoverableException("Cannot log wireless traffic to ethernet-configured Wireshark.");
            }
        }

        private void DetachMedium(INetworkLog<INetworkInterface> reporter)
        {
            lock(innerLock)
            {
                if(observedMedium.Contains(reporter))
                {
                    observedMedium.Remove(reporter);
                    reporter.FrameProcessed -= SendProcessedFrame;
                }
                else
                {
                    throw new RecoverableException("Wireshark doesn't contain this medium");
                }
            }
        }

        private void DetachInterface(INetworkInterface iface)
        {
            var removed = false;

            lock(innerLock)
            {
                foreach(var i in observedInterfaces)
                {
                    if(i.Value.Contains(iface))
                    {
                        i.Value.Remove(iface);
                        removed = true;
                    }
                }
            }

            if(!removed)
            {
                throw new RecoverableException("Wireshark doesn't contain this interface");
            }

        }

        private void AddMedium(INetworkLog<INetworkInterface> reporter)
        {
            lock(innerLock)
            {
                if(!observedMedium.Contains(reporter))
                {
                    observedMedium.Add(reporter);
                    wiresharkSender.TryOpenWireshark();
                    reporter.FrameProcessed += SendProcessedFrame;
                }
                else
                {
                    if(!wiresharkSender.TryOpenWireshark())
                    {
                        throw new RecoverableException("The medium is already being logged in this Wireshark instance.");
                    }
                }
            }
        }

        private void AddInterface(INetworkLog<INetworkInterface> reporter, INetworkInterface iface)
        {
            lock(innerLock)
            {
                if(observedInterfaces.ContainsKey(reporter))
                {
                    if(!observedInterfaces[reporter].Contains(iface))
                    {
                        observedInterfaces[reporter].Add(iface);
                        wiresharkSender.TryOpenWireshark();
                        reporter.FrameTransmitted += SendTransmittedFrame;
                        reporter.FrameProcessed += SendTransmittedFrame;
                    }
                    else
                    {
                        if(!wiresharkSender.TryOpenWireshark())
                        {
                            throw new RecoverableException("The interface is already being logged in this Wireshark instance.");
                        }
                    }
                }
                else
                {
                    observedInterfaces.Add(reporter, new List<INetworkInterface>() { iface });
                    wiresharkSender.TryOpenWireshark();
                    reporter.FrameTransmitted += SendTransmittedFrame;
                    reporter.FrameProcessed += SendTransmittedFrame;
                }
            }
        }

        private void ClearLog()
        {
            lock(innerLock)
            {
                observedInterfaces.Clear();
                observedMedium.Clear();
                wiresharkSender.CloseWireshark();
                wiresharkSender.ClearPipe();
            }
        }

        private void OnMachineRemoved(Machine machine)
        {
            lock(innerLock)
            {
                var observedCopy = new Dictionary<IExternal, List<INetworkInterface>>(observedInterfaces);

                foreach(var external in observedCopy)
                {
                    foreach(var iface in external.Value.ToList())
                    {
                        if(iface is IPeripheral && machine.IsRegistered((IPeripheral)iface))
                        {
                            observedInterfaces[external.Key].Remove(iface);
                        }
                    }

                    if(observedInterfaces[external.Key].Count == 0)
                    {
                        observedInterfaces.Remove(external.Key);
                    }
                }

                if(observedInterfaces.Count == 0 && observedMedium.Count == 0)
                {
                    currentEmulation.MachineRemoved -= OnMachineRemoved;
                    ClearLog();
                    currentEmulation.HostMachine.RemoveHostMachineElement(this);
                }
            }
        }

        private void SendProcessedFrame(IExternal reporter, INetworkInterface sender, byte[] buffer)
        {
            lock(innerLock)
            {
                wiresharkSender.SendProcessedFrames(buffer);
            }
        }

        private void SendTransmittedFrame(IExternal reporter, INetworkInterface sender, INetworkInterface receiver, byte[] buffer)
        {
            lock(innerLock)
            {
                if(observedInterfaces.ContainsKey(reporter)
                   && (observedInterfaces[reporter].Contains(sender) || observedInterfaces[reporter].Contains(receiver)))
                {
                    wiresharkSender.SendReportedFrames(buffer);
                }
            }
        }

        private void SendTransmittedFrame(IExternal reporter, INetworkInterface sender, byte[] buffer)
        {
            lock(innerLock)
            {
                if(observedInterfaces.ContainsKey(reporter) && observedInterfaces[reporter].Contains(sender))
                {
                    wiresharkSender.SendReportedFrames(buffer);
                }
            }
        }

        private readonly object innerLock = new object();
        private WiresharkSender wiresharkSender;
        private string wiresharkSinkName;
        private Dictionary<IExternal, List<INetworkInterface>> observedInterfaces = new Dictionary<IExternal, List<INetworkInterface>>();
        private HashSet<IExternal> observedMedium = new HashSet<IExternal>();
        private LinkLayer layer;
        private Emulation currentEmulation;

        private Dictionary<Type, LinkLayer> mediumToLinkLayer = new Dictionary<Type, LinkLayer>
        {
            {typeof(Switch), LinkLayer.Ethernet},
            {typeof(WirelessMedium), LinkLayer.Wireless_802_15_4},
        };
    }
}
