//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Core;
using Antmicro.Renode.Time;
using Antmicro.Renode.Logging;

namespace Antmicro.Renode.Peripherals.Mocks
{
    public class PeripheralWithAliases : IPeripheral
    {
        public PeripheralWithAliases(
            int normalParameter,
            PeripheralModes mode,
            [NameAlias("ctorAlias")] int aliasedParameter,
            [NameAlias("ctorAliasDefault", warnOnUsage: false)] int aliasedParameterDefault = 0
        )
        {
            this.InfoLog("{0} = {1}", nameof(normalParameter), normalParameter);
            this.InfoLog("{0} = {1}", nameof(mode), mode);
            this.InfoLog("{0} = {1}", nameof(aliasedParameter), aliasedParameter);
            this.InfoLog("{0} = {1}", nameof(aliasedParameterDefault), aliasedParameterDefault);
        }

        public void Reset()
        {
        }

        [NameAlias("Modes")]
        public enum PeripheralModes
        {
            Mode1,
            Mode2,
        }
    }
}
