//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.Testing;
using Antmicro.Renode.Peripherals.Network;

namespace Antmicro.Renode.RobotFramework
{
    internal class NetworInterfaceKeywords : TestersProvider<NetworkInterfaceTester, IMACInterface>, IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public int CreateNetworkInterfaceTester(string networkInterface, string machine = null)
        {
            return CreateNewTester(p => new NetworkInterfaceTester(p), networkInterface, machine);
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
