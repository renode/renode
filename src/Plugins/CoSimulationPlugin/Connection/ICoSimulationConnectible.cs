//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Plugins.CoSimulationPlugin.Connection;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public interface ICoSimulationConnectible
    {
        void OnConnectionAttached(CoSimulationConnection connection);

        void OnConnectionDetached(CoSimulationConnection connection);

        int RenodeToCosimIndex { get; }

        int CosimToRenodeIndex { get; }
    }
}