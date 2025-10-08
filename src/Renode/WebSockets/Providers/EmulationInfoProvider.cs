//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Analyzers;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.UserInterface;
using Antmicro.Renode.WebSockets.Misc;

using AntShell.Commands;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Antmicro.Renode.WebSockets.Providers
{
    public class EmulationInfoProvider : IWebSocketAPIProvider
    {
        public EmulationInfoProvider()
        {
            currentMonitorPrefix = "(monitor) ";
            currentMonitorPrefixColor = System.ConsoleColor.DarkRed;
            isEmulationCleared = false;
        }

        public bool Start(WebSocketAPISharedData sharedData)
        {
            SharedData = sharedData;
            SharedData.ClearEmulationEvent += ClearEmulationEventHandler;
            SharedData.NewClientConnection += NewClientConnectionEventHandler;
            RegisterEvents();
            return true;
        }

        [WebSocketAPIAction("spawn", "1.5.0")]
        private WebSocketAPIResponse SpawnAction(string _, bool __)
        {
            SharedData.MainConnection = SharedData.CurrentConnection;
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("kill", "1.5.0")]
        private WebSocketAPIResponse KillAction(string _)
        {
            SharedData.ClearEmulationEvent?.Invoke();
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("status", "1.5.0")]
        private WebSocketAPIResponse StatusAction(string _)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("command", "1.5.0")]
        private WebSocketAPIResponse CommandAction(string _)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("exec-renode", "1.5.0")]
        private WebSocketAPIResponse ExecRenodeAction(string command, ExecRenodeActionArgs args)
        {
            var argData = new ExecRenodeArgParserData()
            {
                MachineName = args?.Machine,
                PeripheralName = args?.Peripheral
            };

            switch(command)
            {
            case "machines":
                return this.GetMachines();
            case "uarts":
                return ExecRenodeArgParser(argData, true, false) ?
                    GPIOData.GetPeripheralsNameOfType<IUART>(argData.Machine) :
                    argData.ErrorMessage;
            case "buttons":
                return ExecRenodeArgParser(argData, true, false) ?
                    GPIOData.GetPeripheralsNameOfType<Button>(argData.Machine) :
                    argData.ErrorMessage;
            case "leds":
                return ExecRenodeArgParser(argData, true, false) ?
                    GPIOData.GetPeripheralsNameOfType<ILed>(argData.Machine) :
                    argData.ErrorMessage;
            case "button-set":
                return ExecRenodeArgParser(argData, true, true) ?
                    GPIOData.ButtonSet(argData.Machine, argData.Peripheral, args.Value.ToObject<bool>()) :
                    argData.ErrorMessage;
            case "sensors":
                return ExecRenodeArgParser(argData, true, false) ?
                    SensorsData.GetSensors(argData.Machine) :
                    argData.ErrorMessage;
            case "sensor-get":
                return ExecRenodeArgParser(argData, false, true) ?
                    SensorsData.GetSensorData(argData.Peripheral, args.Type) :
                    argData.ErrorMessage;
            case "sensor-set":
                return ExecRenodeArgParser(argData, false, true) ?
                    SensorsData.SetSensorData(argData.Peripheral, args.Type, args.Value) :
                    argData.ErrorMessage;
            }

            return WebSocketAPIUtils.CreateEmptyActionResponse("unknown action");
        }

        [WebSocketAPIAction("exec-monitor", "1.5.0")]
        private WebSocketAPIResponse ExecMonitorAction(List<string> commands)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.WriteLine("", null);
            var result = commands.Select(c => ExecuteCommand(c, interaction) ?? "").ToArray();
            interaction.Write(currentMonitorPrefix, currentMonitorPrefixColor);
            return WebSocketAPIUtils.CreateActionResponse(result);
        }

        private WebSocketAPIResponse GetMachines()
        {
            var machines = EmulationManager.Instance.CurrentEmulation.Names;
            return WebSocketAPIUtils.CreateActionResponse(machines);
        }

        private void RegisterEvents()
        {
            monitor = ObjectCreator.Instance.GetSurrogate(typeof(Antmicro.Renode.UserInterface.Monitor)) as Antmicro.Renode.UserInterface.Monitor;
            monitor.Quitted += SignalRenodeQuitEvent;
            monitor.MachineChanged += MonitorMachineChangedEventHandler;
            if(!(monitor.Interaction is CommandInteractionWrapper))
            {
                monitor.Interaction = new CommandInteractionWrapper(monitor.Interaction);
            }

            var emulationManager = EmulationManager.Instance;
            emulationManager.EmulationChanged += EmulationChangedEventHandler;
            emulationManager.EmulationChanged += SignalClearCommand;
            EmulationChangedEventHandler();
        }

        private void SignalRenodeQuitEvent()
        {
            RenodeQuitEvent.RaiseEventWithoutBody();
        }

        private void SignalClearCommand()
        {
            ClearCommandEvent.RaiseEventWithoutBody();
        }

        private void ClearEmulationEventHandler()
        {
            isEmulationCleared = true;
        }

        private void NewClientConnectionEventHandler()
        {
            if(isEmulationCleared)
            {
                isEmulationCleared = false;
                var interaction = monitor.Interaction as CommandInteractionWrapper;
                interaction.Clear();
                interaction.Write(EmulationManager.Instance.VersionString);
                interaction.WriteLine();
                interaction.WriteLine();
                interaction.Write(currentMonitorPrefix, currentMonitorPrefixColor);
            }
        }

        private void MonitorMachineChangedEventHandler(string machine)
        {
            if(machine is null)
            {
                currentMonitorPrefix = "(monitor) ";
                currentMonitorPrefixColor = System.ConsoleColor.DarkRed;
                return;
            }

            currentMonitorPrefix = $"({machine}) ";
            currentMonitorPrefixColor = System.ConsoleColor.DarkYellow;
        }

        private void EmulationChangedEventHandler()
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            emulation.MachineAdded += EmulationMachineAddedEventHandler;
            emulation.BackendManager.PeripheralBackendAnalyzerCreated += SignalPeripheralBackendAnalyzerCreatedEvent;
        }

        private void EmulationMachineAddedEventHandler(IMachine machine)
        {
            machine.PeripheralsChanged += MachinePeripheralsChangedEventHandler;
        }

        private void MachinePeripheralsChangedEventHandler(IMachine machine, PeripheralsChangedEventArgs args)
        {
            var peripheral = args.Peripheral;

            if(args.Operation == PeripheralsChangedEventArgs.PeripheralChangeType.Addition)
            {
                var machineName = EmulationManager.Instance.CurrentEmulation[machine];

                if(peripheral is LED)
                {
                    var ledPeripheral = peripheral as LED;
                    ledPeripheral.StateChanged += (led, val) => LedStateChangedEvent.RaiseEvent(new PeripheralStateChangedEventDto
                    {
                        MachineName = machineName,
                        Name = GPIOData.GetPeripheralFullName(ledPeripheral),
                        Value = val
                    });
                }
                else if(peripheral is Button)
                {
                    var buttonPeripheral = peripheral as Button;
                    buttonPeripheral.StateChanged += (val) => ButtonStateChangedEvent.RaiseEvent(new PeripheralStateChangedEventDto
                    {
                        MachineName = machineName,
                        Name = GPIOData.GetPeripheralFullName(buttonPeripheral),
                        Value = val
                    });
                }
            }
        }

        private void SignalPeripheralBackendAnalyzerCreatedEvent(IAnalyzableBackendAnalyzer backendAnalyzer)
        {
            var webSocketUartAnalyzer = backendAnalyzer as WebSocketUartAnalyzer;
            if(webSocketUartAnalyzer != null)
            {
                var uart = webSocketUartAnalyzer.UART;
                var machine = uart.GetMachine();

                var machineName = EmulationManager.Instance.CurrentEmulation[machine];
                string uartName = GPIOData.GetPeripheralFullName(uart);

                UartCreatedEvent.RaiseEvent(new UartCreatedEventDto
                {
                    Name = uartName,
                    Port = webSocketUartAnalyzer.GetUartNumber(),
                    MachineName = machineName
                });
            }
        }

        private string ExecuteCommand(string command, CommandInteractionWrapper interaction)
        {
            interaction.Clear();
            interaction.Write(currentMonitorPrefix, currentMonitorPrefixColor);
            interaction.WriteLine(command);

            if(!monitor.Parse(command))
            {
                return $"Could not execute command '{command}': {interaction?.GetError()}";
            }

            var error = interaction.GetError();
            if(!string.IsNullOrEmpty(error))
            {
                return $"There was an error when executing command '{command}': {error}";
            }

            return interaction.GetContents();
        }

        private bool ExecRenodeArgParser(ExecRenodeArgParserData data, bool machineRequired, bool peripheralRequired)
        {
            if((machineRequired || peripheralRequired) && (data.MachineName is null || !EmulationManager.Instance.CurrentEmulation.TryGetMachine(data.MachineName, out data.Machine)))
            {
                data.ErrorMessage = WebSocketAPIUtils.CreateEmptyActionResponse("provided machine does not exists");
                return false;
            }

            if(peripheralRequired && (data.PeripheralName is null || !data.Machine.TryGetByName<IPeripheral>(data.PeripheralName, out data.Peripheral)))
            {
                data.ErrorMessage = WebSocketAPIUtils.CreateEmptyActionResponse("provided peripheral does not exists");
                return false;
            }

            return true;
        }

        private bool isEmulationCleared;
        private string currentMonitorPrefix;
        private Monitor monitor;
        private WebSocketAPISharedData SharedData;
        private System.ConsoleColor currentMonitorPrefixColor;

        // 649:  Field '...' is never assigned to, and will always have its default value null
#pragma warning disable 649
        [WebSocketAPIEvent("uart-opened", "1.5.0")]
        private readonly WebSocketAPIEventHandler UartCreatedEvent;

        [WebSocketAPIEvent("led-state-changed", "1.5.0")]
        private readonly WebSocketAPIEventHandler LedStateChangedEvent;

        [WebSocketAPIEvent("button-state-changed", "1.5.0")]
        private readonly WebSocketAPIEventHandler ButtonStateChangedEvent;

        [WebSocketAPIEvent("renode-quitted", "1.5.0")]
        private readonly WebSocketAPIEventHandler RenodeQuitEvent;

        [WebSocketAPIEvent("clear-command", "1.5.0")]
        private readonly WebSocketAPIEventHandler ClearCommandEvent;
#pragma warning restore 649

        public class ExecRenodeActionArgs
        {
            [JsonProperty("machine", Required = Required.Default)]
            public string Machine;
            [JsonProperty("peripheral", Required = Required.Default)]
            public string Peripheral;
            [JsonProperty("type", Required = Required.Default)]
            public string Type;
            [JsonProperty("value", Required = Required.Default)]
            public JToken Value;
        }

        private class UartCreatedEventDto
        {
            [JsonProperty("port")]
            public int Port;
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("machineName")]
            public string MachineName;
        }

        private class PeripheralStateChangedEventDto
        {
            [JsonProperty("machineName")]
            public string MachineName;
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("value")]
            public bool Value;
        }

        private class ExecRenodeArgParserData
        {
            [JsonProperty("machineName")]
            public string MachineName;
            [JsonProperty("peripheralName")]
            public string PeripheralName;
            [JsonProperty("machine")]
            public IMachine Machine;
            [JsonProperty("peripheral")]
            public IPeripheral Peripheral;
            [JsonProperty("errorMessage")]
            public WebSocketAPIResponse ErrorMessage;
        }
    }
}