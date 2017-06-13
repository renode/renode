//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using Emul8.Core;
using Emul8.Exceptions;
using System.IO;
using Emul8.Peripherals.Wireless;
using Emul8.Peripherals.Network;
using Emul8.Utilities;
using Emul8.Peripherals;
using Emul8;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public static class INetworkLogExtensions
    {
        public static Wireshark CreateWiresharkForWireless(this Emulation emulation, string name)
        {
            return CreateWireshark(emulation, name, LinkLayer.Wireless_802_15_4);
        }

        public static Wireshark CreateWiresharkForEthernet(this Emulation emulation, string name)
        {
            return CreateWireshark(emulation, name, LinkLayer.Ethernet);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<IRadio> reporter)
        {
            var result = CreateWiresharkForWireless(emulation, GetName(reporter));
            result.LogToWireshark(reporter);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<IRadio> reporter, IRadio iface)
        {
            var result = CreateWiresharkForWireless(emulation, GetName(iface));
            result.LogToWireshark(reporter, iface);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<IMACInterface> reporter)
        {
            var result = CreateWiresharkForWireless(emulation, GetName(reporter));
            result.LogToWireshark(reporter);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<IMACInterface> reporter, IMACInterface iface)
        {
            var result = CreateWiresharkForWireless(emulation, GetName(iface));
            result.LogToWireshark(reporter, iface);
        }

        private static Wireshark CreateWireshark(this Emulation emulation, string name, LinkLayer layer)
        {
            Wireshark result;

#if EMUL8_PLATFORM_WINDOWS
            throw new RecoverableException("Wireshark is not available on Windows");
#elif EMUL8_PLATFORM_OSX
            throw new RecoverableException("Wireshark is not available on OS X.");
#else
            if(File.Exists(ConfigurationManager.Instance.Get("wireshark", "wireshark-path", "/usr/bin/wireshark")))
            {
                result = new Wireshark(name, layer);
            }
            else
            {
                throw new RecoverableException("Wireshark is not installed or is not available in the default path. Please adjust the path in Renode configuration.");
            }
#endif
            emulation.HostMachine.AddHostMachineElement(result, name);
            return result;
        }

        private static string GetName(IEmulationElement element)
        {
            string elementName;
            var emulation = EmulationManager.Instance.CurrentEmulation;
            emulation.TryGetEmulationElementName(element, out elementName);
            if(element is IExternal)
            {
                return "{0}-{1}".FormatWith(WiresharkExternalPrefix, elementName);
            }
            //Either IExternal or IPeripheral, so we cast safely
            string machineName;
            Machine machine;
            emulation.TryGetMachineForPeripheral(element as IPeripheral, out machine);
            machineName = emulation[machine];
            return "{0}-{1}-{2}".FormatWith(WiresharkExternalPrefix, machineName, elementName);
        }

        private const string WiresharkExternalPrefix = "wireshark";
    }
}
