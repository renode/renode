//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Emul8.Plugins;
using Emul8.UserInterface;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    [Plugin(Name = "Wireshark Plugin", Version = "1.0", Description = "Provides Wireshark integration for network inspection.", Vendor = "Antmicro")]
    public sealed class WiresharkPlugin : IDisposable
    {
        public WiresharkPlugin(Monitor monitor)
        {
        }

        public void Dispose()
        {
        }
    }
}
