//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

namespace Antmicro.Renode.Peripherals.SystemC
{
    public unsafe interface ISystemCNativeConnection
    {
        void* RenodeBridgeRef { get; set; }

        delegate* unmanaged<void*, RenodeMessage, void> SendBackwardResponseNative { get; set; }

        delegate* unmanaged<void*, DMIMessage, void> SendBackwardResponseDmiNative { get; set; }

        delegate* unmanaged<void*, RenodeMessage, void> SendForwardRequestNative { get; set; }

        void HandleBackwardRequestFromNative(RenodeMessage message);

        void HandleForwardResponseFromNative(RenodeMessage message);

        bool TryInitNativeConnection();

        void TeardownNativeConnection();
    }
}