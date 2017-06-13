//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System.Collections.Generic;
using Emul8.Peripherals.Wireless;
using Emul8.Core;
using Emul8.Peripherals.Network;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public class Wireshark : IHostMachineElement, IExternal
    {
        public Wireshark(string sinkName, LinkLayer layer)
        {
            EmulationManager.Instance.EmulationChanged += ClearLog;
            wiresharkSinkName = sinkName;
            wiresharkSender = new WiresharkSender(wiresharkSinkName, (uint)layer, this);
        }

        public void LogToWireshark(INetworkLog<IRadio> reporter)
        {
            OpenWireshark(reporter);
            reporter.FrameProcessed += SendProcessedFrame;
        }

        public void LogToWireshark(INetworkLog<IRadio> reporter, IRadio iface)
        {
            OpenWireshark(reporter);
            AddInterface(iface);
            reporter.FrameTransmitted += ReportFrame;
        }

        public void LogToWireshark(INetworkLog<IMACInterface> reporter)
        {
            OpenWireshark(reporter);
            reporter.FrameProcessed += SendProcessedFrame;
        }

        public void LogToWireshark(INetworkLog<IMACInterface> reporter, IMACInterface iface)
        {
            OpenWireshark(reporter);
            AddInterface(iface);
            reporter.FrameTransmitted += ReportFrame;
        }

        public void RemoveInterface(IRadio iface)
        {
            if(interfacesList.Contains(iface))
            {
                interfacesList.Remove(iface);
            }
        }

        private void ClearLog()
        {
            if(wiresharkSender != null)
            {
                wiresharkSender.CloseWireshark();
                wiresharkSender.ClearPipe();
                interfacesList.Clear();
            }
        }

        private void AddInterface<T>(T iface)
        {
            interfacesList.Add(iface);
        }

        private void OpenWireshark<T>(INetworkLog<T> reporter)
        {
            if(wiresharkSender != null)
            {
                if(!wiresharkSender.IsConnected)
                {
                    wiresharkSender.OpenWireshark();
                }
            }
            else
            {
                CreateWireshark(reporter);
                wiresharkSender.OpenWireshark();
            }
        }

        private void CreateWireshark<T>(INetworkLog<T> reporter)
        {
            if(typeof(T) == typeof(IRadio))
            {
                wiresharkSender = new WiresharkSender(wiresharkSinkName, (uint)LinkLayer.Wireless_802_15_4, this);
            }
            if(typeof(T) == typeof(IMACInterface))
            {
                wiresharkSender = new WiresharkSender(wiresharkSinkName, (uint)LinkLayer.Ethernet, this);
            }
        }

        private void SendProcessedFrame(byte[] buffer)
        {
            wiresharkSender.SendProcessedFrames(buffer);
        }

        private void ReportFrame<T>(T sender, T receiver, byte[] buffer)
        {
            if(interfacesList.Contains(sender))
            {
                SendReportedFrames(buffer);
            }
        }

        private void SendReportedFrames(byte[] buffer)
        {
            wiresharkSender.SendReportedFrames(buffer);
        }

        private WiresharkSender wiresharkSender;
        private string wiresharkSinkName;
        private List<object> interfacesList = new List<object>();
    }
}
