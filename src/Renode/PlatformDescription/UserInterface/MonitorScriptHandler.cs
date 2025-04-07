//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.PlatformDescription.Syntax;
using Antmicro.Renode.UserInterface;

namespace Antmicro.Renode.PlatformDescription.UserInterface
{
    public sealed class MonitorScriptHandler : IScriptHandler
    {
        public MonitorScriptHandler(Machine machine, Monitor monitor)
        {
            this.machine = machine;
            this.monitor = monitor;
        }

        public void Execute(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler)
        {
            var entry = scriptable as Entry;
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

        public void RegisterReset(IScriptable scriptable, IEnumerable<string> statements, Action<string> errorHandler)
        {
            var entry = scriptable as Entry;
            string name;
            IPeripheral receiver;

            if(entry.Variable.Value is Machine)
            {
                name = Machine.MachineKeyword;
                receiver = null;
            }
            else if(machine.TryGetAnyName((IPeripheral)entry.Variable.Value, out name))
            {
                receiver = (IPeripheral)entry.Variable.Value;
            }
            else
            {
                errorHandler("The reset section is only allowed for peripherals that are registered.");
                return;
            }

            var macroContent = new StringBuilder();
            foreach(var monitorCommand in statements.Select(x => string.Format("{0} {1}", name, x)))
            {
                macroContent.AppendLine(monitorCommand);
            }
            monitor.SetPeripheralMacro(receiver, "reset", macroContent.ToString(), machine);
        }

        public bool ValidateInit(IScriptable scriptable, out string message)
        {
            var entry = scriptable as Entry;
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