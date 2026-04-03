using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Hooks;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;

using Newtonsoft.Json;

namespace Antmicro.Renode.WebSockets.Providers
{
    public class RemoteExecutionProvider : IWebSocketAPIProvider
    {
        public RemoteExecutionProvider()
        { }

        public bool Start(WebSocketAPISharedData sharedData)
        {
            this.SharedData = sharedData;
            var emulationManager = EmulationManager.Instance;
            emulationManager.EmulationChanged += EmulationChangedEventHandler;

            EmulationChangedEventHandler();
            return true;
        }

        private void EmulationChangedEventHandler()
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            emulation.MachineStateChanged += MachineStateChangedEventHandler;
            emulation.MachineAdded += MachineAddedEventHandler;

            EmulatorStateChangedEvent.RaiseEvent(new EmulatorStateChangedEventData
            {
                Value = "emulation-cleared"
            });
        }

        private void MachineStateChangedEventHandler(IMachine machine, MachineStateChangedEventArgs args)
        {
            switch(args.CurrentState)
            {
            case MachineStateChangedEventArgs.State.Started:
                EmulatorStateChangedEvent.RaiseEvent(new EmulatorStateChangedEventData
                {
                    Value = "machine-started"
                });
                break;

            case MachineStateChangedEventArgs.State.Paused:
                EmulatorStateChangedEvent.RaiseEvent(new EmulatorStateChangedEventData
                {
                    Value = "machine-paused"
                });
                break;
            }
        }

        private void MachineAddedEventHandler(IMachine machine)
        {
            machine.PeripheralsChanged += MachinePeripheralsChangedEventHandler;
            machine.SystemBus.OnUnhandledAccess += UnhandledAccessHandler;
        }

        private void MachinePeripheralsChangedEventHandler(IMachine machine, PeripheralsChangedEventArgs args)
        {
            if(args.Operation == PeripheralsChangedEventArgs.PeripheralChangeType.Addition)
            {
                var cpu = args.Peripheral as TranslationCPU;
                if(cpu != null)
                {
                    cpu.OnFunctionCall += FunctionCallHandler;
                }
            }
        }

        private void UnhandledAccessHandler(UnhandledAccess access)
        {
            UnhandledAccessEvent.RaiseEvent(new UnhandledAccessEventData
            {
                Name = access.Symbol?.Name ?? "<unknown>",
                PC = access.PC,
                Write = access.Access == Access.Write,
                Address = access.Address,
                Width = (int)access.AccessWidth,
                Value = access.Value
            });
        }

        private void FunctionCallHandler(ICpuSupportingGdb cpu, ulong address, Symbol symbol)
        {
            var entry = address == symbol.Start;
            FunctionCallEvent.RaiseEvent(new FunctionCallEventData
            {
                Name = symbol.Name,
                Entry = entry
            });
        }

        [WebSocketAPIAction("set-program-counter", "1.5.0")]
        private WebSocketAPIResponse SetProgramCounter(string symbol)
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;

            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                foreach(var cpu in machine.SystemBus.GetCPUs())
                {
                    if(machine.SystemBus.TryGetAllSymbolAddresses(symbol, out var addressesEnumerable, cpu))
                    {
                        var pc = addressesEnumerable.First();
                        cpu.PC = pc;
                        return WebSocketAPIUtils.CreateEmptyActionResponse();
                    }
                }
            }

            return WebSocketAPIUtils.CreateEmptyActionResponse("Symbol not found");
        }

        [WebSocketAPIAction("add-pause", "1.5.0")]
        private WebSocketAPIResponse AddPause(List<string> symbols)
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                foreach(var symbol in symbols)
                {
                    machine.SystemBus.AddPauseHookAtSymbol(symbol);
                }
            }
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("write-memory", "1.5.0")]
        private WebSocketAPIResponse WriteMemory(ulong address, string base64EncodedData)
        {
            byte[] data = Convert.FromBase64String(base64EncodedData);
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                machine.SystemBus.WriteBytes(data, address);
            }

            return WebSocketAPIUtils.CreateActionResponse(data.Length);
        }

        [WebSocketAPIAction("read-memory", "1.5.0")]
        private WebSocketAPIResponse ReadMemory(ulong address, int width)
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                var data = machine.SystemBus.ReadBytes(address, width);
                string base64EncodedData = Convert.ToBase64String(data);
                return WebSocketAPIUtils.CreateActionResponse(base64EncodedData);
            }
        }

        [WebSocketAPIAction("write-registers", "1.5.0")]
        private WebSocketAPIResponse WriteRegisters(Dictionary<int, ulong> registers)
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                var cpu = machine.SystemBus.GetCPUs().FirstOrDefault();
                var armCPU = cpu as Antmicro.Renode.Peripherals.CPU.Arm;
                if(cpu == null)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse("No Arm CPU found in the current machine");
                }
                else
                {
                    foreach(var register in registers)
                    {
                        armCPU.SetRegister(register.Key, (RegisterValue)register.Value);
                    }
                    return WebSocketAPIUtils.CreateEmptyActionResponse();
                }
            }
        }

        [WebSocketAPIAction("read-registers", "1.5.0")]
        private WebSocketAPIResponse ReadRegisters()
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                var cpu = machine.SystemBus.GetCPUs().FirstOrDefault();
                var armCPU = cpu as Antmicro.Renode.Peripherals.CPU.Arm;
                if(cpu == null)
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse("No Arm CPU found in the current machine");
                }
                else
                {
                    var registers = armCPU.GetRegisters();
                    var result = new Dictionary<int, ulong>();
                    foreach(var register in registers)
                    {
                        result.Add(register.Index, armCPU.GetRegister(register.Index));
                    }
                    return WebSocketAPIUtils.CreateActionResponse(result);
                }
            }
        }

        [WebSocketAPIAction("set-constant", "1.5.0")]
        private WebSocketAPIResponse SetConstant(ulong address, string name, ulong width, ulong value)
        {
            var emulationManager = EmulationManager.Instance;
            var emulation = emulationManager.CurrentEmulation;
            var machine = emulation.Machines.FirstOrDefault();
            if(machine == null)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("No machine found in the current emulation");
            }
            else
            {
                var range = new Antmicro.Renode.Core.Range(address, width);
                machine.SystemBus.Tag(range, name, value, overridePeripheralAccesses: true);
                return WebSocketAPIUtils.CreateEmptyActionResponse();
            }
        }

        private WebSocketAPISharedData SharedData;

        // 649:  Field '...' is never assigned to, and will always have its default value null
#pragma warning disable 649
        [WebSocketAPIEvent("emulation-state-changed", "1.5.0")]
        private readonly WebSocketAPIEventHandler EmulatorStateChangedEvent;

        [WebSocketAPIEvent("unhandled-access", "1.5.0")]
        private readonly WebSocketAPIEventHandler UnhandledAccessEvent;

        [WebSocketAPIEvent("function-call", "1.5.0")]
        private readonly WebSocketAPIEventHandler FunctionCallEvent;
#pragma warning restore 649

        private class EmulatorStateChangedEventData
        {
            [JsonProperty("value")]
            public string Value;
        }

        private class UnhandledAccessEventData
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("pc")]
            public ulong PC;
            [JsonProperty("write")]
            public bool Write;
            [JsonProperty("address")]
            public ulong Address;
            [JsonProperty("width")]
            public int Width;
            [JsonProperty("value")]
            public ulong Value;
        }

        private class FunctionCallEventData
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("entry")]
            public bool Entry;
        }
    }
}