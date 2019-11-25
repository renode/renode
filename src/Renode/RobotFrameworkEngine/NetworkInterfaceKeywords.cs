//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Peripherals.Network;
using Antmicro.Renode.Peripherals.Wireless;

namespace Antmicro.Renode.RobotFramework
{
    internal class NetworInterfaceKeywords : TestersProvider<NetworkInterfaceTester, INetworkInterface>, IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public int CreateNetworkInterfaceTester(string networkInterface, string machine = null)
        {
            return CreateNewTester(p => {
                        if(p is IMACInterface mac)
                        {
                            return new NetworkInterfaceTester(mac);
                        }
                        if(p is IRadio radio)
                        {
                            return new NetworkInterfaceTester(radio);
                        }
                        throw new KeywordException($"Could not create NetworkInterfaceTester from {p}.");
                    }, networkInterface, machine);
        }

        [RobotFrameworkKeyword]
        public NetworkInterfaceTesterResult WaitForOutgoingPacket(int timeout, int? testerId = null)
        {
            if(!GetTesterOrThrowException(testerId).TryWaitForOutgoingPacket(timeout, out var packet))
            {
                throw new KeywordException("No packet received in the expected time frame.");
            }

            return packet;
        }

        [RobotFrameworkKeyword]
        public NetworkInterfaceTesterResult WaitForOutgoingPacketWithBytesAtIndex(string bytes, int index, int maxPackets, int singleTimeout, int? testerId = null)
        {
            if(!GetTesterOrThrowException(testerId).TryWaitForOutgoingPacketWithBytesAtIndex(bytes, index, maxPackets, singleTimeout, out var packet))
            {
                throw new KeywordException("Requested packet not received in the expected time frame.");
            }

            return packet;
        }
    }
}
