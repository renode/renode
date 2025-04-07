//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Wireless;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public class BLESniffer
    {
        public byte[] InsertHeaderToPacket(IRadio sender, byte[] originalPacket)
        {
            byte[] completePacket = new byte[originalPacket.Length + SnifferMetadataSizeInBytes];

            // If packet is shorter than minimal acceptable or channel is out of range then communication is broken
            // and we can abort sniffing anything.
            if(originalPacket.Length < MinimalBLEPacketLength)
            {
                sender.Log(LogLevel.Error, "BLE packet size is {0} bytes. Expected at least {1} bytes.", originalPacket.Length, MinimalBLEPacketLength);
                FillRestOfData(originalPacket, completePacket, SnifferMetadataSizeInBytes);
                return completePacket;
            }

            if(!channelToWiresharkIndex.TryGetValue(sender.Channel, out var wiresharkIndex))
            {
                sender.Log(LogLevel.Error, "Channel number {0} doesn't exist in bluetooth specification.", sender.Channel);
                FillRestOfData(originalPacket, completePacket, SnifferMetadataSizeInBytes);
                return completePacket;
            }

            completePacket[0] = wiresharkIndex;

            // Signal Power
            completePacket[1] = 0x0;

            // Noise Power
            completePacket[2] = 0x0;

            // Access Address Offenses
            completePacket[3] = 0x0;

            // Reference Access Address
            completePacket[4] = originalPacket[0];
            completePacket[5] = originalPacket[1];
            completePacket[6] = originalPacket[2];
            completePacket[7] = originalPacket[3];

            var flags = (short)SnifferFlags.PacketDeWhitened | (short)SnifferFlags.SignalPowerIsValid | (short)SnifferFlags.NoisePowerIsValid | (short)SnifferFlags.PacketIsDecrypted
                                    | (short)SnifferFlags.ReferenceAccessAddressIsValid | (short)SnifferFlags.AccessAddressOffensesIsValid | (short)SnifferFlags.CRCWasChecked
                                    | (short)SnifferFlags.CRCIsValid | (short)SnifferFlags.MICWasChecked | (short)SnifferFlags.MICIsValid;

            var accessAddress = BitHelper.ToUInt32(originalPacket, 0, 4, true);

            // Here we check whether we have an advertisement packet or data packet. We're using access address embedded in packet.
            if(accessAddress != AdvertisementAccessAddress)
            {
                // If an accessAddress is a key in the dictionary then we know that sender belongs to this connection.
                // There is an assumption that data packets are sent after advertisement packets. If there is no key that matches access address then something went wrong.
                // If sender is a value for this key then it's a master, otherwise it's a slave.
                if(!mastersInConnections.TryGetValue(accessAddress, out var masterRadio))
                {
                    sender.Log(LogLevel.Error, "There is no connection associated with accessAddress: 0x{0:X}.", accessAddress);
                    FillRestOfData(originalPacket, completePacket, SnifferMetadataSizeInBytes);
                    return completePacket;
                }

                if(masterRadio == sender)
                {
                    flags |= (short)PDUTypeNumbers.DataPacketMasterToSlave;
                }
                else
                {
                    flags |= (short)PDUTypeNumbers.DataPacketSlaveToMaster;
                }
            }
            else
            {
                flags |= (short)PDUTypeNumbers.Advertisement;

                // When CONNECT_IND packet (PDU type 5) is sent we can read from PDU payload what access address will be used for this connection.
                // This way we can save connection's access address and which radio is a master for this connection.
                var pduType = originalPacket[4] & 0xF;
                if(pduType == ConnectPDUType)
                {
                    if(originalPacket.Length < ConnectBLEPacketLength)
                    {
                        sender.Log(LogLevel.Error, "Connect packet size is {0} bytes. Expected at least {1} bytes.", originalPacket.Length, ConnectBLEPacketLength);
                        FillRestOfData(originalPacket, completePacket, SnifferMetadataSizeInBytes);
                        return completePacket;
                    }

                    // Extract an accessAddress for connection from PDU payload.
                    var newAccessAddress = BitHelper.ToUInt32(originalPacket, 18, 4, true);
                    if(mastersInConnections.ContainsKey(newAccessAddress))
                    {
                        // connection with this access address already exists, so we override it
                        sender.Log(LogLevel.Warning, "There is already a connection associated with access address: 0x{0:X}. Overriding old connection.", newAccessAddress);
                        mastersInConnections[newAccessAddress] = sender;
                    }
                    else
                    {
                        mastersInConnections.Add(newAccessAddress, sender);
                    }
                }

                // Sniffer just sets an appropriate flag in header to indicate that it's auxiliary advertisement packet.
                else if(pduType == AuxiliaryAdvertisementPDUType)
                {
                    flags |= (short)PDUTypeNumbers.AuxiliaryAdvertisement;
                }
            }

            // Embed flags to the packet.
            completePacket[8] = (byte)flags;
            completePacket[9] = (byte)(flags >> 8);

            FillRestOfData(originalPacket, completePacket, SnifferMetadataSizeInBytes);
            return completePacket;
        }

        private void FillRestOfData(byte[] src, byte[] dest, int offset)
        {
            for(int i = 0; i < src.Length; i++)
            {
                dest[i + offset] = src[i];
            }
        }

        // Wireshark indexes channels from 0 to 39 basing on the frequency meanwhile in reality channels 37, 38 and 39
        // are in different places of frequency spectrum. This is why we have to remap channel numbers to indexed for Wireshark.
        private readonly Dictionary<int, byte> channelToWiresharkIndex = new Dictionary<int, byte>()
        {
            { 37, 0 },
            { 0, 1 },
            { 1, 2 },
            { 2, 3 },
            { 3, 4 },
            { 4, 5 },
            { 5, 6 },
            { 6, 7 },
            { 7, 8 },
            { 8, 9 },
            { 9, 10 },
            { 10, 11 },
            { 38, 12 },
            { 11, 13 },
            { 12, 14 },
            { 13, 15 },
            { 14, 16 },
            { 15, 17 },
            { 16, 18 },
            { 17, 19 },
            { 18, 20 },
            { 19, 21 },
            { 20, 22 },
            { 21, 23 },
            { 22, 24 },
            { 23, 25 },
            { 24, 26 },
            { 25, 27 },
            { 26, 28 },
            { 27, 29 },
            { 28, 30 },
            { 29, 31 },
            { 30, 32 },
            { 31, 33 },
            { 32, 34 },
            { 33, 35 },
            { 34, 36 },
            { 35, 37 },
            { 36, 38 },
            { 39, 39 },
        };

        // This dictionary holds an information about all connections. Each connection is identified by an access address
        // and there is only one master device associated with each access address. Other devices associated with access addressses
        // are considered to be slaves.
        private readonly Dictionary<uint, IRadio> mastersInConnections = new Dictionary<uint, IRadio>();

        private const int SnifferMetadataSizeInBytes = 10;
        private const int MinimalBLEPacketLength = 9;
        private const int ConnectBLEPacketLength = 43;
        private const uint AdvertisementAccessAddress = 0x8e89bed6;
        private const byte ConnectPDUType = 5;
        private const byte AuxiliaryAdvertisementPDUType = 7;

        // Flags registers are made of a bitfield and pdu type numbers
        [Flags]
        private enum SnifferFlags : short
        {
            None = 0x0,
            PacketDeWhitened = 0x1,
            SignalPowerIsValid = 0x2,
            NoisePowerIsValid = 0x4,
            PacketIsDecrypted = 0x8,
            ReferenceAccessAddressIsValid = 0x10,
            AccessAddressOffensesIsValid = 0x20,
            RFChannelIsLikelyToBeDistorted = 0x40,
            CRCWasChecked = 0x400,
            CRCIsValid = 0x800,
            MICWasChecked = 0x1000,
            MICIsValid = 0x2000,
        }

        private enum PDUTypeNumbers : short
        {
            Advertisement = 0x0 << 7,
            AuxiliaryAdvertisement = 0x1 << 7,
            DataPacketMasterToSlave = 0x2 << 7,
            DataPacketSlaveToMaster = 0x3 << 7
        }
    }
}