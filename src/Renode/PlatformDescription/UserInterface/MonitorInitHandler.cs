//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.PlatformDescription.Syntax;
using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.PlatformDescription.UserInterface
{
    public sealed class MonitorInitHandler : IInitHandler
    {
        public MonitorInitHandler(Machine machine, Monitor monitor)
        {
            this.machine = machine;
            this.monitor = monitor;
        }

        public void Execute(IInitable initable, IEnumerable<string> statements, Action<string> errorHandler)
        {
            var entry = initable as Entry;
            string name;
            if(entry.Variable.Value is Machine)
            {
                name = Machine.MachineKeyword;
            }
            else if(!machine.TryGetAnyName((IPeripheral)entry.Variable.Value, out name))
            {
                errorHandler("The init section is only allowed for peripherals that are registered.");
                return;
            }
            foreach(var monitorCommand in statements.Select(x => string.Format("{0} {1}", name, x)))
            {
                monitor.Parse(monitorCommand);
            }
        }

        public bool Validate(IInitable initable, out string message)
        {
            var entry = initable as Entry;
            if(entry == null)
            {
                message = "The init section is only allowed for entries.";
                return false;
            }
            message = null;
            return true;
        }

        private readonly Machine machine;
        private readonly Monitor monitor;
    }
}
