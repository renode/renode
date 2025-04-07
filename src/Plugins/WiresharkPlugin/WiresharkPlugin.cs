//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    [Plugin(Name = "Wireshark Plugin", Version = "1.0", Description = "Provides Wireshark integration for network inspection.", Vendor = "Antmicro")]
    public sealed class WiresharkPlugin : IDisposable
    {
        public WiresharkPlugin(Monitor _)
        {
        }

        public void Dispose()
        {
        }
    }
}