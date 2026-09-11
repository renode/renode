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
        void* RenodeConnectionRef { get; set; }

        delegate* unmanaged<void*, RenodeMessage, void> SendBackwardResponseNative { get; set; }

        delegate* unmanaged<void*, DMIMessage, void> SendBackwardResponseDmiNative { get; set; }

        delegate* unmanaged<void*, RenodeMessage, RenodeMessage*, DMINativeMessage*, int> SendForwardRequestNative { get; set; }

        uint SpinWaitIterations { get; }

        void HandleBackwardRequestFromNative(RenodeMessage message);

        bool TryInitNativeConnection();

        void TeardownNativeConnection();
    }
}
