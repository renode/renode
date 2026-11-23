//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Analyzers;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CAN;
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.Peripherals.SPI;
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

        [WebSocketAPIAction("kill")]
        private WebSocketAPIResponse KillAction(string _)
        {
            SharedData.ClearEmulationEvent?.Invoke();
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("status")]
        private WebSocketAPIResponse StatusAction(string _)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("command")]
        private WebSocketAPIResponse CommandAction(string _)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("exec-renode")]
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
                    Utils.GetPeripheralsNameOfType<IUART>(argData.Machine) :
                    argData.ErrorMessage;
            case "buttons":
                return ExecRenodeArgParser(argData, true, false) ?
                    Utils.GetPeripheralsNameOfType<Button>(argData.Machine) :
                    argData.ErrorMessage;
            case "leds":
                return ExecRenodeArgParser(argData, true, false) ?
                    Utils.GetPeripheralsNameOfType<ILed>(argData.Machine) :
                    argData.ErrorMessage;
            case "button-set":
                return ExecRenodeArgParser(argData, true, true) ?
                    GPIOData.ButtonSet(argData.Machine, argData.Peripheral, args.Value.ToObject<bool>()) :
                    argData.ErrorMessage;
            case "spis":
                return ExecRenodeArgParser(argData, true, false) ?
                    Utils.GetPeripheralsNameOfType<ISPIController>(argData.Machine) :
                    argData.ErrorMessage;
            }

            return WebSocketAPIUtils.CreateEmptyActionResponse("unknown action");
        }

        [WebSocketAPIAction("sensor-list")]
        private WebSocketAPIResponse SensorList(string machine)
        {
            var argData = new ExecRenodeArgParserData()
            {
                MachineName = machine,
            };

            if(!ExecRenodeArgParser(argData, true, false))
            {
                return argData.ErrorMessage;
            }

            return SensorsData.GetSensors(argData.Machine);
        }

        [WebSocketAPIAction("sensor-source-read")]
        private WebSocketAPIResponse SensorSourceRead(string machine, string peripheral, string measurand, string type)
        {
            var argData = new ExecRenodeArgParserData()
            {
                MachineName = machine,
                PeripheralName = peripheral,
            };

            if(!ExecRenodeArgParser(argData, false, true))
            {
                return argData.ErrorMessage;
            }

            return SensorsData.GetSensorData(argData.Peripheral, measurand, type);
        }

        [WebSocketAPIAction("sensor-source-set")]
        private WebSocketAPIResponse SensorSourceSet(string machine, string peripheral, string measurand, string type, JToken data)
        {
            var argData = new ExecRenodeArgParserData()
            {
                MachineName = machine,
                PeripheralName = peripheral,
            };

            if(!ExecRenodeArgParser(argData, false, true))
            {
                return argData.ErrorMessage;
            }

            return SensorsData.SetSensorData(argData.Peripheral, measurand, type, data);
        }

        [WebSocketAPIAction("sensor-source-set-relative")]
        private WebSocketAPIResponse SensorSourceSetRelative(string machine, string peripheral, string measurand, string type, JToken data)
        {
            var argData = new ExecRenodeArgParserData()
            {
                MachineName = machine,
                PeripheralName = peripheral,
            };

            if(!ExecRenodeArgParser(argData, false, true))
            {
                return argData.ErrorMessage;
            }

            return SensorsData.SetSensorDataRelative(argData.Peripheral, measurand, type, data);
        }

        [WebSocketAPIAction("exec-monitor")]
        private WebSocketAPIResponse ExecMonitorAction(List<string> commands)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.WriteLine("", null);
            var result = commands.Select(c => ExecuteCommand(c, interaction) ?? "").ToArray();
            interaction.Write(currentMonitorPrefix, currentMonitorPrefixColor);
            return WebSocketAPIUtils.CreateActionResponse(result);
        }

        [WebSocketAPIAction("term-resize")]
        private WebSocketAPIResponse TerminalResize(string endpoint, int width, int height)
        {
            var conns = WebSocketsManager.Instance.GetConnections(endpoint);
            foreach(var connection in conns)
            {
                connection.TriggerResize(width, height);
            }
            return WebSocketAPIUtils.CreateActionResponse("ok");
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
            monitor.RegisterUICommandHandler((action, arguments) => SignalUIActionEvent(action, arguments));

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

        private void SignalUIActionEvent(string action, IDictionary<string, object> arguments)
        {
            UICommandEvent.RaiseEvent(new UIActionEventDto
            {
                Action = action,
                Arguments = arguments,
            });
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
                        Name = Utils.GetPeripheralFullName(ledPeripheral),
                        Value = val
                    });
                }
                else if(peripheral is Button)
                {
                    var buttonPeripheral = peripheral as Button;
                    buttonPeripheral.StateChanged += (val) => ButtonStateChangedEvent.RaiseEvent(new PeripheralStateChangedEventDto
                    {
                        MachineName = machineName,
                        Name = Utils.GetPeripheralFullName(buttonPeripheral),
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
                string uartName = Utils.GetPeripheralFullName(uart);

                UartCreatedEvent.RaiseEvent(new UartCreatedEventDto
                {
                    Name = uartName,
                    MachineName = machineName
                });
            }

            var webSocketVideoAnalyzer = backendAnalyzer as WebSocketVideoAnalyzer;
            if(webSocketVideoAnalyzer != null)
            {
                var video = webSocketVideoAnalyzer.Video;
                var machine = video.GetMachine();

                var machineName = EmulationManager.Instance.CurrentEmulation[machine];
                string displayName = machine.GetAnyNameOrTypeName(video);

                DisplayCreatedEvent.RaiseEvent(new DisplayCreatedEventDto
                {
                    Name = displayName,
                    MachineName = machineName
                });
            }
            var webSocketCANAnalyzer = backendAnalyzer as WebSocketCANAnalyzer;
            if(webSocketCANAnalyzer != null)
            {
                var canHub = ((CANBackend)webSocketCANAnalyzer.Backend).CANHub;

                CANCreatedEvent.RaiseEvent(new CANCreatedEventDto
                {
                    HubName = EmulationManager.Instance.CurrentEmulation.ExternalsManager.TryGetName(canHub, out var hubName) ? hubName : ""
                });
            }
            var webSocketSPIAnalyzer = backendAnalyzer as WebSocketSPIAnalyzer;
            if(webSocketSPIAnalyzer != null)
            {
                var spiController = webSocketSPIAnalyzer.SPIController;
                var machine = spiController.GetMachine();
                var machineName = EmulationManager.Instance.CurrentEmulation[machine];
                var spiName = machine.GetAnyNameOrTypeName(spiController);

                SPIOpenedEvent.RaiseEvent(new SPICreatedEventDto
                {
                    Name = spiName,
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
        [WebSocketAPIEvent("uart-opened")]
        private readonly WebSocketAPIEventHandler UartCreatedEvent;

        [WebSocketAPIEvent("display-opened")]
        private readonly WebSocketAPIEventHandler DisplayCreatedEvent;

        [WebSocketAPIEvent("can-opened")]
        private readonly WebSocketAPIEventHandler CANCreatedEvent;

        [WebSocketAPIEvent("led-state-changed")]
        private readonly WebSocketAPIEventHandler LedStateChangedEvent;

        [WebSocketAPIEvent("button-state-changed")]
        private readonly WebSocketAPIEventHandler ButtonStateChangedEvent;

        [WebSocketAPIEvent("renode-quitted")]
        private readonly WebSocketAPIEventHandler RenodeQuitEvent;

        [WebSocketAPIEvent("clear-command")]
        private readonly WebSocketAPIEventHandler ClearCommandEvent;

        [WebSocketAPIEvent("spi-opened")]
        private readonly WebSocketAPIEventHandler SPIOpenedEvent;

        [WebSocketAPIEvent("ui-command")]
        private readonly WebSocketAPIEventHandler UICommandEvent;
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
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("machineName")]
            public string MachineName;
        }

        private class DisplayCreatedEventDto
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("machineName")]
            public string MachineName;
        }

        private class CANCreatedEventDto
        {
            [JsonProperty("hubName")]
            public string HubName;
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

        private class UIActionEventDto
        {
            [JsonProperty("action")]
            public string Action;
            [JsonProperty("arguments")]
            public IDictionary<string, object> Arguments;
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

        private class SPICreatedEventDto
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("machineName")]
            public string MachineName;
        }
    }
}
