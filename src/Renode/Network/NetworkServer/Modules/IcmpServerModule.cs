//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Net;
using System.Net.NetworkInformation;
using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure;
using Antmicro.Renode.Logging;
using PacketDotNet;
using PacketDotNet.Utils;

namespace Antmicro.Renode.Network
{
    public class IcmpServerModule : IExternal
    {
        public IcmpServerModule(NetworkServer MyParentServer, IPAddress serverIP, MACAddress serverMAC)
        {
            IP = serverIP;
            MAC = serverMAC;
            ParentServer = MyParentServer;
        }
        private MACAddress MAC { get; set; }
        private IPAddress IP { get; set; }
        private NetworkServer ParentServer { get; set; }

        /// <summary>
        /// Handles the IPv4 packet with an ICMPv4 request by replying to it if the request is supported
        /// </summary>
        public void HandleIcmpPacket(Action<EthernetFrame> frameReady, IPv4Packet ipv4PacketRequest,
            PhysicalAddress icmpDestinationAddress)
        {
            ParentServer.Log(LogLevel.Noisy, "Handling ICMP packet: {0}", (ICMPv4Packet)ipv4PacketRequest.PayloadPacket);
            if(!CreateIcmpResponse(ipv4PacketRequest, out var icmpv4PacketResponse))
            {
                ParentServer.Log(LogLevel.Warning, "Failed to create an ICMPv4 response for this packet: {0}", (ICMPv4Packet)ipv4PacketRequest.PayloadPacket);
                return;
            }
            var ipv4PacketResponse = CreateIPv4Packet(ipv4PacketRequest);
            if(!CreateEthernetFramePacket(ipv4PacketResponse, icmpv4PacketResponse, icmpDestinationAddress, out var response))
            {
                ParentServer.Log(LogLevel.Warning, "Failed to create an EthernetFramePacket response for this packet: {0}", (ICMPv4Packet)ipv4PacketRequest.PayloadPacket);
                return;
            }

            ParentServer.Log(LogLevel.Noisy, "Sending EthernetFrame with a response: {0}", response.ToString());
            frameReady?.Invoke(response);
        }


        /// <summary>
        /// Checks if a given ICMPv4 request is supported, and if so, creates a reply
        /// </summary>
        private bool CreateIcmpResponse(IPv4Packet ipv4PacketRequest, out ICMPv4Packet icmpPacketResponse)
        {
            icmpPacketResponse = null;

            ParentServer.Log(LogLevel.Noisy, "Handling ICMP packet: {0}", (ICMPv4Packet)ipv4PacketRequest.PayloadPacket);
            if(!GetReplyIfRequestSupported(ipv4PacketRequest, out var byteReply))
            {
                return false;
            }

            icmpPacketResponse = CreateIcmpv4Packet(ipv4PacketRequest, byteReply);
            ParentServer.Log(LogLevel.Noisy, "Created an ICMPv4 response: {0}", icmpPacketResponse);
            return true;
        }


        /// <summary>
        /// Checks if the destination address matches our IP,
        /// and creates a reply if we support a given request
        /// </summary>
        private bool GetReplyIfRequestSupported(IPv4Packet ipv4PacketRequest, out byte[] byteReply)
        {
            byteReply = new byte[8];
            var ipv4PacketPayload = (ICMPv4Packet)ipv4PacketRequest.PayloadPacket;

            if(!ipv4PacketRequest.DestinationAddress.Equals(IP))
            {
                ParentServer.Log(LogLevel.Warning, "The destination IP is not equal to server IP, request ignored: {0}", ipv4PacketPayload);
                return false;
            }
            ParentServer.Log(LogLevel.Noisy, "The IP address is equal to server IP, trying to service the request: {0}", ipv4PacketPayload);

            if(!ipv4PacketPayload.TypeCode.Equals(ICMPv4TypeCodes.EchoRequest))
            {
                ParentServer.Log(LogLevel.Warning, "Unsupported ICMP code: {0}",
                    ipv4PacketPayload);
                return false;
            }

            BitConverter.GetBytes((ushort)ICMPv4TypeCodes.EchoReply).CopyTo(byteReply, 0);
            ParentServer.Log(LogLevel.Noisy, "Created a {0} byte reply to the ICMP request", byteReply.Length);
            return true;
        }


        /// <summary>
        /// Creates an ICMPv4 packet. Copies ID, Sequence Number and Data from a given an ICMPv4 request
        /// </summary>
        private ICMPv4Packet CreateIcmpv4Packet(IPv4Packet ipv4PackeRequest, byte[] byteReply)
        {
            ParentServer.Log(LogLevel.Noisy, "Creating an ICMPv4 response packet");
            var icmpv4PacketRequest = (ICMPv4Packet)ipv4PackeRequest.PayloadPacket;
            var byteArrayReply = new ByteArraySegment(byteReply);
            var icmpv4PacketResponse = new ICMPv4Packet(byteArrayReply)
            {
                /****************************************************************

                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |     Type      |     Code      |          Checksum             |
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |           Identifier          |        Sequence Number        |
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |      Internet Header + 64 bits of Original Data Datagram      |
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                
                ****************************************************************/
                // We can copy that from request packet because they are the same in the request and the reply
                Data = new byte[icmpv4PacketRequest.Data.Length]
            };
            for (var i = 0; i < icmpv4PacketResponse.Data.Length; i++) icmpv4PacketResponse.Data[i] = 0;
            icmpv4PacketRequest.Data.CopyTo(icmpv4PacketResponse.Data, 0);
            icmpv4PacketResponse.ID = icmpv4PacketRequest.ID;
            icmpv4PacketResponse.Sequence = icmpv4PacketRequest.Sequence;

            ParentServer.Log(LogLevel.Noisy, "Created ICMPv4 response packet: {0}", icmpv4PacketResponse.PayloadPacket);
            return icmpv4PacketResponse;
        }


        /// <summary>
        /// Creates an IPv4 response packet from a given IPv4 packet
        /// </summary>
        private IPv4Packet CreateIPv4Packet(IPv4Packet ipv4PacketRequest)
        {
            var ipv4PacketResponse = new IPv4Packet(IP, ipv4PacketRequest.SourceAddress);
            ParentServer.Log(LogLevel.Noisy, "Created IPv4 packet response: {0}", ipv4PacketResponse);
            return ipv4PacketResponse;
        }


        /// <summary>
        /// Creates an Ethernet Frame from a given IPv4, and ICMPv4 packet
        /// </summary>
        private bool CreateEthernetFramePacket(IPv4Packet ipv4PacketResponse, ICMPv4Packet icmpv4PacketResponse,
            PhysicalAddress icmpDestinationAddress, out EthernetFrame response)
        {
            ParentServer.Log(LogLevel.Noisy, "Creating EthernetFramePacket response");
            ipv4PacketResponse.PayloadPacket = icmpv4PacketResponse;

            var ethernetResponse = new EthernetPacket((PhysicalAddress)MAC,
                icmpDestinationAddress,
                EthernetPacketType.None)
            {
                PayloadPacket = ipv4PacketResponse
            };

            ethernetResponse.RecursivelyUpdateCalculatedValues(new[] { EthernetPacketType.IpV4 }, new[] { PacketDotNet.IPProtocolType.ICMP });


            if(!EthernetFrame.TryCreateEthernetFrame(ethernetResponse.Bytes,
                true, out response))
            {
                ParentServer.Log(LogLevel.Warning, "Failed to create EthernetFrame response");
                return false;
            }
            ParentServer.Log(LogLevel.Noisy, "Created EthernetFramePacket response: {0}", response.ToString());

            return true;
        }
    }
}
