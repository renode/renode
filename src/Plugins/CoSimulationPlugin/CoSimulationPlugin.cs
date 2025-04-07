//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.Plugins.CoSimulationPlugin
{
    [Plugin(Name = "Cosimulation Plugin", Version = "1.0", Description = "Provides Verilog simulation integration.", Vendor = "Antmicro")]
    public sealed class CoSimulationPlugin : IDisposable
    {
        public CoSimulationPlugin(Monitor _)
        {
        }

        public void Dispose()
        {
        }
    }
}