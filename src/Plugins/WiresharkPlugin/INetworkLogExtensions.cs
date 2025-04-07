//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;

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
        public static void CreateWiresharkForBLE(this Emulation emulation, string name)
        {
            CreateBLEConfiguredWireshark(emulation, name);
        }

        public static void CreateWiresharkForIEEE802_15_4(this Emulation emulation, string name)
        {
            CreateIEEE802_15_4ConfiguredWireshark(emulation, name);
        }

        public static void CreateWiresharkForCAN(this Emulation emulation, string name)
        {
            CreateCANConfiguredWireshark(emulation, name);
        }

        public static void CreateWiresharkForEthernet(this Emulation emulation, string name)
        {
            CreateEthernetConfiguredWireshark(emulation, name);
        }

        public static void LogToWireshark<T>(this Emulation emulation, INetworkLog<T> reporter, T iface) where T : INetworkInterface
        {
            GetConfiguredWireshark(emulation, reporter as INetworkLog<INetworkInterface>, GetName(reporter, iface)).LogToWireshark(reporter as INetworkLog<INetworkInterface>, iface);
        }

        public static void LogToWireshark(this Emulation emulation, INetworkLog<INetworkInterface> reporter)
        {
            GetConfiguredWireshark(emulation, reporter, GetName(reporter)).LogToWireshark(reporter);
        }

        public static void LogBLETraffic(this Emulation emulation)
        {
            var result = CreateBLEConfiguredWireshark(emulation, BLELogName);
            foreach(var ble in emulation.ExternalsManager.GetExternalsOfType<BLEMedium>())
            {
                result.LogToWireshark((INetworkLog<INetworkInterface>)ble);
            }

            // We detach the event before reattaching it to ensure that we are connected only once.
            // This manouver allows us not to use an additional variable, which would be difficult
            // to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        public static void LogIEEE802_15_4Traffic(this Emulation emulation)
        {
            var result = CreateIEEE802_15_4ConfiguredWireshark(emulation, IEEE802_15_4LogName);
            foreach(var ieee802_15_4 in emulation.ExternalsManager.GetExternalsOfType<IEEE802_15_4Medium>())
            {
                result.LogToWireshark((INetworkLog<INetworkInterface>)ieee802_15_4);
            }

            // We detach the event before reattaching it to ensure that we are connected only once.
            // This manouver allows us not to use an additional variable, which would be difficult
            // to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        public static void LogEthernetTraffic(this Emulation emulation)
        {
            var result = CreateEthernetConfiguredWireshark(emulation, EthernetLogName);
            foreach(var ethernet in emulation.ExternalsManager.GetExternalsOfType<Switch>())
            {
                result.LogToWireshark((INetworkLog<INetworkInterface>)ethernet);
            }

            // We detach the event before reattaching it to ensure that we are connected only once.
            // This manouver allows us not to use an additional variable, which would be difficult
            // to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        public static void LogCANTraffic(this Emulation emulation)
        {
            var result = CreateCANConfiguredWireshark(emulation, CANLogName);
            foreach(var hub in emulation.ExternalsManager.GetExternalsOfType<CANHub>())
            {
                result.LogToWireshark((INetworkLog<INetworkInterface>)hub);
            }

            // We detach the event before reattaching it to ensure that we are connected only once.
            // This manouver allows us not to use an additional variable, which would be difficult
            // to reset, as it is a static class.
            emulation.ExternalsManager.ExternalsChanged -= AddExternal;
            emulation.ExternalsManager.ExternalsChanged += AddExternal;
        }

        private static void AddExternal(ExternalsManager.ExternalsChangedEventArgs reporter)
        {
            var external = reporter.External;
            var bleResult = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(BLELogName, out var bleWiresharkFound);
            var ieee802_15_4Result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(IEEE802_15_4LogName, out var ieee802_15_4WiresharkFound);
            var ethernetResult = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(EthernetLogName, out var ethernetWiresharkFound);
            var canResult = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(CANLogName, out var canWiresharkFound);

            if(ieee802_15_4WiresharkFound && external is IEEE802_15_4Medium)
            {
                ieee802_15_4Result.LogToWireshark((IEEE802_15_4Medium)external);
            }

            if(bleWiresharkFound && external is BLEMedium)
            {
                bleResult.LogToWireshark((BLEMedium)external);
            }

            if(ethernetWiresharkFound && external is Switch)
            {
                ethernetResult.LogToWireshark((Switch)external);
            }

            if(canWiresharkFound && external is CANHub)
            {
                canResult.LogToWireshark((CANHub)external);
            }
        }

        private static Wireshark GetConfiguredWireshark(Emulation emulation, INetworkLog<INetworkInterface> reporter, string hostName)
        {
            if(reporter is IEEE802_15_4Medium)
            {
                return CreateIEEE802_15_4ConfiguredWireshark(emulation, hostName);
            }
            else if(reporter is BLEMedium)
            {
                return CreateBLEConfiguredWireshark(emulation, hostName);
            }
            else if(reporter is Switch)
            {
                return CreateEthernetConfiguredWireshark(emulation, hostName);
            }
            else if(reporter is CANHub)
            {
                return CreateCANConfiguredWireshark(emulation, hostName);
            }
            else
            {
                throw new ArgumentException("Expected CANHub, Switch, BLEMedium or IEEE802_15_4Medium.");
            }
        }

        private static Wireshark CreateBLEConfiguredWireshark(Emulation emulation, string name)
        {
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out var bleWiresharkFound);

            if(bleWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.Bluetooth_LE);
        }

        private static Wireshark CreateIEEE802_15_4ConfiguredWireshark(Emulation emulation, string name)
        {
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out var wirelessWiresharkFound);

            if(wirelessWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.IEEE802_15_4);
        }

        private static Wireshark CreateEthernetConfiguredWireshark(Emulation emulation, string name)
        {
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out var ethernetWiresharkFound);

            if(ethernetWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.Ethernet);
        }

        private static Wireshark CreateCANConfiguredWireshark(Emulation emulation, string name)
        {
            var result = (Wireshark)EmulationManager.Instance.CurrentEmulation.HostMachine.TryGetByName(name, out var canWiresharkFound);

            if(canWiresharkFound)
            {
                return result;
            }

            return CreateWireshark(emulation, name, LinkLayer.CAN);
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
                throw new RecoverableException($"Wireshark is not installed or is not available in the default path. Please adjust the path in the Renode configuration file ({ConfigurationManager.Instance.FilePath}).");
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
        private const string BLELogName = WiresharkExternalPrefix + "-" + "allBLETraffic";
        private const string IEEE802_15_4LogName = WiresharkExternalPrefix + "-" + "allIEEE802_15_4Traffic";
        private const string EthernetLogName = WiresharkExternalPrefix + "-" + "allEthernetTraffic";
        private const string CANLogName = WiresharkExternalPrefix + "-" + "allCANTraffic";
#if PLATFORM_WINDOWS
        private const string WiresharkPath = @"c:\Program Files\Wireshark\Wireshark.exe";
#elif PLATFORM_OSX
        private const string WiresharkPath = "/Applications/Wireshark.app/Contents/MacOS/Wireshark";
#else
        private const string WiresharkPath = "/usr/bin/wireshark";
#endif
    }
}