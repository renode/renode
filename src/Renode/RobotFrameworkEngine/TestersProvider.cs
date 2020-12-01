//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;

namespace Antmicro.Renode.RobotFramework
{
    internal abstract class TestersProvider<TTester, TPeripheral> where TPeripheral: class, IEmulationElement
    {
        public TestersProvider()
        {
            testers = new Dictionary<int, TTester>();
            peripheralsWithTesters = new HashSet<TPeripheral>();
            EmulationManager.Instance.EmulationChanged += () =>
            {
                lock(testers)
                {
                    testers.Clear();
                    peripheralsWithTesters.Clear();
                }
            };
        }

        public int CreateNewTester(Func<TPeripheral, TTester> creator, string peripheralName, string machine = null)
        {
            lock(testers)
            {
                Machine machineObject;
                if(machine == null)
                {
                    if(!EmulationManager.Instance.CurrentEmulation.Machines.Any())
                    {
                        throw new KeywordException("There is no machine in the emulation. Could not create tester for peripheral: {0}", peripheralName);
                    }
                    machineObject = EmulationManager.Instance.CurrentEmulation.Machines.Count() == 1
                        ? EmulationManager.Instance.CurrentEmulation.Machines.First()
                        : null;
                    if(machineObject == null)
                    {
                        throw new KeywordException("No machine name provided. Don't know which one to choose. Available machines: [{0}]",
                            string.Join(", ", EmulationManager.Instance.CurrentEmulation.Machines.Select(x => EmulationManager.Instance.CurrentEmulation[x])));
                    }
                }
                else if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(machine, out machineObject))
                {
                    throw new KeywordException("Machine with name {0} not found. Available machines: [{1}]", machine,
                            string.Join(", ", EmulationManager.Instance.CurrentEmulation.Machines.Select(x => EmulationManager.Instance.CurrentEmulation[x])));
                }

                if(!machineObject.TryGetByName(peripheralName, out IPeripheral typeLessPeripheral))
                {
                    throw new KeywordException("Peripheral for machine '{0}' not found or of wrong type: '{1}'. Available peripherals: [{2}]", machine, peripheralName,
                            string.Join(", ", machineObject.GetAllNames()));
                }
                var peripheral = typeLessPeripheral as TPeripheral;
                if(peripheral == null)
                {
                    throw new KeywordException("Peripheral for machine '{0}' not found or of wrong type: '{1}'. Available peripherals: [{2}]", machine, peripheralName,
                            string.Join(", ", machineObject.GetAllNames()));
                }

                if(peripheralsWithTesters.Contains(peripheral))
                {
                    throw new KeywordException("Tester for peripheral '{0}' in machine '{1}' already exists", peripheralName, machine);
                }

                var tester = creator(peripheral);
                peripheralsWithTesters.Add(peripheral);
                testers.Add(peripheralsWithTesters.Count, tester);
            }
            return peripheralsWithTesters.Count;
        }

        protected TTester GetTesterOrThrowException(int? testerId)
        {
            lock(testers)
            {
                TTester tester;
                if(testerId == null)
                {
                    if(testers.Count != 1)
                    {
                        throw new KeywordException("There is more than one tester available - please specify ID of the desired tester.");
                    }
                    tester = testers.Single().Value;
                }
                else if(!testers.TryGetValue(testerId.Value, out tester))
                {
                    throw new KeywordException("Tester for given ID={0} was not found. Did you forget to create the tester?", testerId);
                }
                return tester;
            }
        }

        private readonly Dictionary<int, TTester> testers;
        private readonly HashSet<TPeripheral> peripheralsWithTesters;
    }
}
