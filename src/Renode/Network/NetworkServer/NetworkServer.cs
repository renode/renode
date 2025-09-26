//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using System.Net;
using System.Net.NetworkInformation;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Network;

using PacketDotNet;

namespace Antmicro.Renode.Network
{
    public static class NetworkServerExtensions
    {
        public static void CreateNetworkServer(this Emulation emulation, string name, string ipAddress)
        {
            emulation.ExternalsManager.AddExternal(new NetworkServer(ipAddress), name);
        }
    }

    public class NetworkServer : IExternal, IMACInterface, IHasChildren<IServerModule>
    {
        public NetworkServer(string ipAddress, string macAddress = null)
        {
            if(!IPAddress.TryParse(ipAddress, out var parsedIP))
            {
                new ConstructionException($"Invalid IP address: {ipAddress}");
            }

            if(macAddress != null)
            {
                if(!MACAddress.TryParse(macAddress, out var parsedMAC))
                {
                    new ConstructionException($"Invalid MAC address: {macAddress}");
                }
                MAC = parsedMAC;
            }
            else
            {
                MAC = new MACAddress(0xdeadbeef);
            }

            IP = parsedIP;

            arpTable = new Dictionary<IPAddress, PhysicalAddress>();
            modules = new Dictionary<int, IServerModule>();
            modulesNames = new Dictionary<string, int>();

            this.Log(LogLevel.Info, "Network server started at IP {0}", IP);
        }

        public IEnumerable<string> GetNames()
        {
            return modulesNames.Keys;
        }

        public IServerModule TryGetByName(string name, out bool success)
        {
            if(!modulesNames.TryGetValue(name, out var port))
            {
                success = false;
                return null;
            }

            success = true;
            return modules[port];
        }

        public bool RegisterModule(IServerModule module, int port, string name)
        {
            if(modules.ContainsKey(port))
            {
                this.Log(LogLevel.Error, "Couldn't register module on port {0} as it's already used", port);
                return false;
            }

            if(modulesNames.ContainsKey(name))
            {
                this.Log(LogLevel.Error, "Couldn't register module by name {0} as it's already used", name);
                return false;
            }

            this.Log(LogLevel.Noisy, "Registering module on port {0}", port);
            modules[port] = module;
            modulesNames[name] = port;
            return true;
        }

        public void ReceiveFrame(EthernetFrame frame)
        {
            var ethernetPacket = frame.UnderlyingPacket;

            this.Log(LogLevel.Noisy, "Ethernet packet details: {0}", frame);
#if DEBUG_PACKETS
            this.Log(LogLevel.Noisy, Misc.PrettyPrintCollectionHex(frame.Bytes));
#endif

            switch(ethernetPacket.Type)
            {
            case EthernetPacketType.Arp:
                if(TryHandleArp((ARPPacket)ethernetPacket.PayloadPacket, out var arpResponse))
                {
                    var ethernetResponse = new EthernetPacket((PhysicalAddress)MAC, ethernetPacket.SourceHwAddress, EthernetPacketType.None);
                    ethernetResponse.PayloadPacket = arpResponse;

                    this.Log(LogLevel.Noisy, "Sending response: {0}", ethernetResponse);
                    EthernetFrame.TryCreateEthernetFrame(ethernetResponse.Bytes, true, out var response);
                    FrameReady?.Invoke(response);
                }
                break;

            case EthernetPacketType.IpV4:
                var ipv4Packet = (IPv4Packet)ethernetPacket.PayloadPacket;
                arpTable[ipv4Packet.SourceAddress] = ethernetPacket.SourceHwAddress;
                HandleIPv4(ipv4Packet);
                break;

            default:
                this.Log(LogLevel.Warning, "Unsupported packet type: {0}", ethernetPacket.Type);
                break;
            }
        }

        public MACAddress MAC { get; set; }

        public IPAddress IP { get; set; }

        public event Action<EthernetFrame> FrameReady;

        private void HandleIPv4(IPv4Packet packet)
        {
            this.Log(LogLevel.Noisy, "Handling IPv4 packet: {0}", PacketToString(packet));

            switch(packet.Protocol)
            {
            case PacketDotNet.IPProtocolType.UDP:
                HandleUdp((UdpPacket)packet.PayloadPacket);
                break;

            default:
                this.Log(LogLevel.Warning, "Unsupported protocol: {0}", packet.Protocol);
                break;
            }
        }

        private void HandleUdp(UdpPacket packet)
        {
            this.Log(LogLevel.Noisy, "Handling UDP packet: {0}", PacketToString(packet));

            if(!modules.TryGetValue(packet.DestinationPort, out var module))
            {
                this.Log(LogLevel.Warning, "Received UDP packet on port {0}, but no service is active", packet.DestinationPort);
                return;
            }

            var src = new IPEndPoint(((IPv4Packet)packet.ParentPacket).SourceAddress, packet.SourcePort);
            module.HandleUdp(src, packet, (s, r) => HandleUdpResponse(s, r));
        }

        private void HandleUdpResponse(IPEndPoint source, UdpPacket response)
        {
            var ipPacket = new IPv4Packet(IP, source.Address);
            var ethernetPacket = new EthernetPacket((PhysicalAddress)MAC, arpTable[source.Address], EthernetPacketType.None);

            ipPacket.PayloadPacket = response;
            ethernetPacket.PayloadPacket = ipPacket;
            response.UpdateCalculatedValues();

            this.Log(LogLevel.Noisy, "Sending UDP response: {0}", response);

            EthernetFrame.TryCreateEthernetFrame(ethernetPacket.Bytes, true, out var ethernetFrame);
            ethernetFrame.FillWithChecksums(new EtherType[] { EtherType.IpV4 }, new[] { IPProtocolType.UDP });

            FrameReady?.Invoke(ethernetFrame);
        }

        private bool TryHandleArp(ARPPacket packet, out ARPPacket response)
        {
            response = null;
            var packetString = PacketToString(packet);
            this.Log(LogLevel.Noisy, "Handling ARP packet: {0}", packetString);

            if(packet.Operation != ARPOperation.Request)
            {
                this.Log(LogLevel.Warning, "Unsupported ARP packet: {0}", packetString);
                return false;
            }

            if(!packet.TargetProtocolAddress.Equals(IP))
            {
                this.Log(LogLevel.Noisy, "This ARP packet is not directed to me. Ignoring");
                return false;
            }

            response = new ARPPacket(
                ARPOperation.Response,
                packet.SenderHardwareAddress,
                packet.SenderProtocolAddress,
                (PhysicalAddress)MAC,
                IP);

            this.Log(LogLevel.Noisy, "Sending ARP response");
            return true;
        }

        private string PacketToString(Packet packet)
        {
            try
            {
                return packet.ToString();
            }
            catch
            {
                return "<failed to decode packet>";
            }
        }

        private readonly Dictionary<int, IServerModule> modules;
        private readonly Dictionary<string, int> modulesNames;
        private readonly Dictionary<IPAddress, PhysicalAddress> arpTable;
    }
}