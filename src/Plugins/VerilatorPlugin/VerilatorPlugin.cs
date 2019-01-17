//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.Plugins.VerilatorPlugin
{
    [Plugin(Name = "Verilator Plugin", Version = "1.0", Description = "Provides Verilog simulation integration.", Vendor = "Antmicro")]
    public sealed class VerilatorPlugin : IDisposable
    {
        public VerilatorPlugin(Monitor monitor)
        {
        }

        public void Dispose()
        {
        }
    }
}
