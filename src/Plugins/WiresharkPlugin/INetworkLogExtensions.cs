//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using Antmicro.Renode;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.Network;
using Antmicro.Renode.Peripherals.Wireless;
using Antmicro.Renode.Tools.Network;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public static class INetworkLogExtensions
    {
        public static void CreateWiresharkForWireless(this Emulation emulation, string name)
        {
            CreateWirelessConfiguredWireshark(emulation, name);
        }

        public static void CreateWiresharkForEthernet(this Emulation emulation, string name)
        {
            CreateEthernetConfiguredWireshark(emulation, name);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<INetworkInterface> reporter, INetworkInterface iface)
        {
            GetConfiguredWireshark(emulation, reporter, GetName(reporter, iface)).LogToWireshark(reporter, iface);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<INetworkInterface> reporter)
        {
            GetConfiguredWireshark(emulation, reporter, GetName(reporter)).LogToWireshark(reporter);
        }

        public static void LogWirelessTraffic(this Emulation emulation)
        {
            var result = CreateWirelessConfiguredWireshark(emulation, WirelessLogName);
            var externals = emulation.ExternalsManager.Externals;
            foreach(var wireless in externals)
            {
                if(wireless is WirelessMedium)
                {
                    result.LogToWireshark((INetworkLog<INetworkInterface>)wireless);
                }
            }

            //We detach the event before reattaching it to ensure that we are connected only once.
            //This manouver allows us not to use an additional variable, which would be difficult
            //to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        public static void LogEthernetTraffic(this Emulation emulation)
        {
            var result = CreateEthernetConfiguredWireshark(emulation, EthernetLogName);
            var externals = emulation.ExternalsManager.Externals;
            foreach(var ethernet in externals)
            {
                if(ethernet is Switch)
                {
                    result.LogToWireshark((INetworkLog<INetworkInterface>)ethernet);
                }
            }

            //We detach the event before reattaching it to ensure that we are connected only once.
            //This manouver allows us not to use an additional variable, which would be difficult
            //to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        private static void AddExternal(ExternalsManager.ExternalsChangedEventArgs reporter)
        {
            var external = reporter.External;
            bool wirelessWiresharkFound;
            bool ethernetWiresharkFound;
            var wirelessResult = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(WirelessLogName, out wirelessWiresharkFound);
            var ethernetResult = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(EthernetLogName, out ethernetWiresharkFound);

            if(wirelessWiresharkFound && external is WirelessMedium)
            {
                wirelessResult.LogToWireshark((WirelessMedium)external);
            }

            if(ethernetWiresharkFound && external is Switch)
            {
                ethernetResult.LogToWireshark((Switch)external);
            }
        }

        private static Wireshark GetConfiguredWireshark(Emulation emulation, INetworkLog<INetworkInterface> reporter, string hostName)
        {
            if(reporter is WirelessMedium)
            {
                return CreateWirelessConfiguredWireshark(emulation, hostName);
            }
            else if(reporter is Switch)
            {
                return CreateEthernetConfiguredWireshark(emulation, hostName);
            }
            else
            {
                throw new ArgumentException("Expected Switch or WirelessMedium.");
            }
        }

        private static Wireshark CreateWirelessConfiguredWireshark(Emulation emulation, string name)
        {
            bool wirelessWiresharkFound;
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out wirelessWiresharkFound);

            if(wirelessWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.Wireless_802_15_4);
        }

        private static Wireshark CreateEthernetConfiguredWireshark(Emulation emulation, string name)
        {
            bool ethernetWiresharkFound;
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out ethernetWiresharkFound);

            if(ethernetWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.Ethernet);
        }

        private static Wireshark CreateWireshark(this Emulation emulation, string name, LinkLayer layer)
        {
            Wireshark result;
            var wiresharkPath = ConfigurationManager.Instance.Get("wireshark", "wireshark-path", WiresharkPath);
            if(File.Exists(wiresharkPath))
            {
                result = new Wireshark(name, layer, wiresharkPath);
            }
            else
            {
                throw new RecoverableException("Wireshark is not installed or is not available in the default path. Please adjust the path in Renode configuration.");
            }

            emulation.HostMachine.AddHostMachineElement(result, name);
            return result;
        }

        private static string GetName(IEmulationElement element, IEmulationElement nextElement = null)
        {
            string elementName;
            var emulation = EmulationManager.Instance.CurrentEmulation;
            emulation.TryGetEmulationElementName(element, out elementName);

            if(nextElement != null)
            {
                string nextElementName;
                emulation.TryGetEmulationElementName(nextElement, out nextElementName);
                nextElementName = nextElementName.Replace(':', '-').Replace('.', '-');
                return "{0}-{1}-{2}".FormatWith(WiresharkExternalPrefix, elementName, nextElementName);
            }

            return "{0}-{1}".FormatWith(WiresharkExternalPrefix, elementName);
        }

        private const string WiresharkExternalPrefix = "wireshark";
        private const string WirelessLogName = WiresharkExternalPrefix + "-" + "allWirelessTraffic";
        private const string EthernetLogName = WiresharkExternalPrefix + "-" + "allEthernetTraffic";
#if PLATFORM_WINDOWS
        private const string WiresharkPath = @"c:\Program Files\Wireshark\Wireshark.exe";
#else
        private const string WiresharkPath = "/usr/bin/wireshark";
#endif
    }
}
