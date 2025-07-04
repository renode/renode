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
        private WebSocketAPIResponse SpawnAction(string name, bool gui)
        {
            SharedData.MainConnection = SharedData.CurrentConnection;
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("kill", "1.5.0")]
        private WebSocketAPIResponse KillAction(string name)
        {
            SharedData.ClearEmulationEvent?.Invoke();
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("status", "1.5.0")]
        private WebSocketAPIResponse StatusAction(string name)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("command", "1.5.0")]
        private WebSocketAPIResponse CommandAction(string name)
        {
            return WebSocketAPIUtils.CreateEmptyActionResponse();
        }

        [WebSocketAPIAction("exec-renode", "1.5.0")]
        private WebSocketAPIResponse ExecRenodeAction(string command, ExecRenodeActionArgs args)
        {
            IMachine machine = null;
            IPeripheral peripheral = null;

            if(!EmulationManager.Instance.CurrentEmulation.TryGetMachine(args.machine, out machine))
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("provided machine does not exist");
            }

            if(args.peripheral != null && !machine.TryGetByName<IPeripheral>(args.peripheral, out peripheral))
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("provided peripheral does not exist");
            }

            switch(command)
            {
            case "uarts":
                return GPIOData.GetPeripheralsNameOfType<IUART>(machine);
            case "buttons":
                return GPIOData.GetPeripheralsNameOfType<Button>(machine);
            case "leds":
                return GPIOData.GetPeripheralsNameOfType<ILed>(machine);
            case "button-set":
                return GPIOData.ButtonSet(machine, peripheral, args.value.ToObject<bool>());
            case "machines":
                return this.GetMachines();
            case "sensors":
                return SensorsData.GetSensors(machine);
            case "sensor-get":
                return SensorsData.GetSensorData(peripheral, args.type);
            case "sensor-set":
                return SensorsData.SetSensorData(peripheral, args.type, args.value);
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
                        machineName = machineName,
                        name = GPIOData.GetPeripheralFullName(ledPeripheral),
                        value = val
                    });
                }
                else if(peripheral is Button)
                {
                    var buttonPeripheral = peripheral as Button;
                    buttonPeripheral.StateChanged += (val) => ButtonStateChangedEvent.RaiseEvent(new PeripheralStateChangedEventDto
                    {
                        machineName = machineName,
                        name = GPIOData.GetPeripheralFullName(buttonPeripheral),
                        value = val
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
                    name = uartName,
                    port = webSocketUartAnalyzer.GetUartNumber(),
                    machineName = machineName
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

        private bool isEmulationCleared;
        private string currentMonitorPrefix;
        private Monitor monitor;
        private WebSocketAPISharedData SharedData;
        private System.ConsoleColor currentMonitorPrefixColor;

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

        public class ExecRenodeActionArgs
        {
            [JsonProperty(Required = Required.Always)]
            public string machine;
            [JsonProperty(Required = Required.Default)]
            public string peripheral;
            [JsonProperty(Required = Required.Default)]
            public string type;
            [JsonProperty(Required = Required.Default)]
            public JToken value;
        }

        private class UartCreatedEventDto
        {
            public int port;
            public string name;
            public string machineName;
        }

        private class PeripheralStateChangedEventDto
        {
            public string machineName;
            public string name;
            public bool value;
        }
    }
}