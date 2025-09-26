//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.ExceptionServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.UserInterface;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    internal class RenodeKeywords : IRobotFrameworkKeywordProvider
    {
        public RenodeKeywords()
        {
            monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
            savepoints = new Dictionary<string, Savepoint>();
            if(!(monitor.Interaction is CommandInteractionWrapper))
            {
                monitor.Interaction = new CommandInteractionWrapper(monitor.Interaction);
            }
        }

        public void Dispose()
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            monitor.Interaction = interaction.UnderlyingCommandInteraction;
            TemporaryFilesManager.Instance.Cleanup();
        }

        [RobotFrameworkKeyword]
        public void ResetEmulation()
        {
            EmulationManager.Instance.Clear();
            Recorder.Instance.ClearEvents();
            if(logTester != null)
            {
                Logger.RemoveBackend(logTester);
                logTester = null;
            }
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void StartEmulation()
        {
            EmulationManager.Instance.CurrentEmulation.StartAll();
        }

        [RobotFrameworkKeyword]
        public string ExecuteCommand(string command, string machine = null)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.Clear();
            SetMonitorMachine(machine);

            if(!monitor.Parse(command))
            {
                throw new KeywordException("Could not execute command '{0}': {1}", command, interaction.GetError());
            }

            var error = interaction.GetError();
            if(!string.IsNullOrEmpty(error))
            {
                throw new KeywordException($"There was an error when executing command '{command}': {error}");
            }

            return interaction.GetContents();
        }

        [RobotFrameworkKeyword]
        public object ExecutePython(string command, string machine = null)
        {
            SetMonitorMachine(machine);

            try
            {
                return monitor.ExecutePythonCommand(command);
            }
            catch(RecoverableException ex)
            {
                // Rethrow the inner exception preserving the stack trace, the return is unreachable
                ExceptionDispatchInfo.Capture(ex.InnerException).Throw();
                return null;
            }
        }

        [RobotFrameworkKeyword]
        // This method accepts array of strings that is later
        // concatenated using single space and parsed by the monitor.
        //
        // Using array instead of a single string allows us to
        // split long commands into several lines using (...)
        // notation in robot script; otherwise it would be impossible
        // as there is no option to split a single parameter.
        public string ExecuteCommand(string[] commandFragments, string machine = null)
        {
            var command = string.Join(" ", commandFragments);
            return ExecuteCommand(command, machine);
        }

        [RobotFrameworkKeyword]
        public string ExecuteScript(string path)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.Clear();

            if(!monitor.TryExecuteScript(path, interaction))
            {
                throw new KeywordException("Could not execute script: {0}", interaction.GetError());
            }

            return interaction.GetContents();
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void StopRemoteServer()
        {
            var robotFrontendEngine = (RobotFrameworkEngine)ObjectCreator.Instance.GetSurrogate(typeof(RobotFrameworkEngine));
            robotFrontendEngine.Shutdown();
        }

        [RobotFrameworkKeyword]
        public void HandleHotSpot(HotSpotAction action)
        {
            var isStarted = EmulationManager.Instance.CurrentEmulation.IsStarted;
            switch(action)
            {
            case HotSpotAction.None:
                // do nothing
                break;
            case HotSpotAction.Pause:
                if(isStarted)
                {
                    EmulationManager.Instance.CurrentEmulation.PauseAll();
                    EmulationManager.Instance.CurrentEmulation.StartAll();
                }
                break;
            case HotSpotAction.Serialize:
                var fileName = TemporaryFilesManager.Instance.GetTemporaryFile();
                var monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
                if(monitor.Machine != null)
                {
                    EmulationManager.Instance.CurrentEmulation.AddOrUpdateInBag("monitor_machine", monitor.Machine);
                }
                EmulationManager.Instance.Save(fileName);
                EmulationManager.Instance.Load(fileName);
                if(EmulationManager.Instance.CurrentEmulation.TryGetFromBag<Machine>("monitor_machine", out var mac))
                {
                    monitor.Machine = mac;
                }
                if(isStarted)
                {
                    EmulationManager.Instance.CurrentEmulation.StartAll();
                }
                break;
            default:
                throw new KeywordException("Hot spot action {0} is not currently supported", action);
            }
        }

        [RobotFrameworkKeyword(replayMode: Replay.Never)]
        public void Provides(string state, ProviderType type = ProviderType.Serialization)
        {
            if(type == ProviderType.Serialization)
            {
                var tempfileName = AllocateTemporaryFile();
                EmulationManager.Instance.CurrentEmulation.TryGetEmulationElementName(monitor.Machine, out var currentMachine);
                EmulationManager.Instance.Save(tempfileName);
                savepoints[state] = new Savepoint(currentMachine, tempfileName);
            }
            Recorder.Instance.SaveCurrentState(state);
        }

        [RobotFrameworkKeyword(replayMode: Replay.Never)]
        public void Requires(string state)
        {
            List<Recorder.Event> events;
            if(!Recorder.Instance.TryGetState(state, out events))
            {
                throw new KeywordException("Required state {0} not found.", state);
            }
            ResetEmulation();
            var robotFrontendEngine = (RobotFrameworkEngine)ObjectCreator.Instance.GetSurrogate(typeof(RobotFrameworkEngine));

            IEnumerable<Recorder.Event> eventsToExecute = events;
            var isSerialized = savepoints.TryGetValue(state, out var savepoint);

            if(isSerialized)
            {
                EmulationManager.Instance.Load(savepoint.Filename);
                if(savepoint.SelectedMachine != null)
                {
                    ExecuteCommand($"mach set \"{savepoint.SelectedMachine}\"");
                }
                eventsToExecute = eventsToExecute.Where(x => (x.ReplayMode == Replay.Always || x.ReplayMode == Replay.InSerializationMode));
            }

            foreach(var e in eventsToExecute)
            {
                robotFrontendEngine.ExecuteKeyword(e.Name, e.Arguments);
            }
        }

        [RobotFrameworkKeyword]
        public void WaitForPause(float timeout)
        {
            var masterTimeSource = EmulationManager.Instance.CurrentEmulation.MasterTimeSource;
            var mre = new System.Threading.ManualResetEvent(false);
            var callback = (Action)(() =>
            {
                // it is possible that the block hook is triggered before virtual time has passed
                // - in such case it should not be interpreted as a machine pause
                if(masterTimeSource.ElapsedVirtualTime.Ticks > 0)
                {
                    mre.Set();
                }
            });

            var timeoutEvent = masterTimeSource.EnqueueTimeoutEvent((uint)(timeout * 1000));

            try
            {
                masterTimeSource.BlockHook += callback;
                System.Threading.WaitHandle.WaitAny(new[] { timeoutEvent.WaitHandle, mre });

                if(timeoutEvent.IsTriggered)
                {
                    throw new KeywordException($"Emulation did not pause in expected time of {timeout} seconds.");
                }
            }
            finally
            {
                masterTimeSource.BlockHook -= callback;
            }
        }

        [RobotFrameworkKeyword]
        public void WaitForGdbConnection(int port, string machine = null, bool pauseToWait = true, bool acceptRunningServer = true)
        {
            IMachine machineObject;
            if(machine == null)
            {
                machineObject = TestersProvider<object, IEmulationElement>.TryGetDefaultMachineOrThrowKeywordException();
            }
            else if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(machine, out machineObject))
            {
                throw new KeywordException("Machine with name {0} not found. Available machines: [{1}]", machine,
                        string.Join(", ", EmulationManager.Instance.CurrentEmulation.Names));
            }

            if(pauseToWait)
            {
                machineObject.PauseAndRequestEmulationPause();
            }

            if(machineObject.IsGdbConnectedToServer(port) && acceptRunningServer)
            {
                // A server is already running, so no need to wait
                return;
            }

            // Since this keyword is likely to be used to manually inspect running application or in issue reproduction cases
            // make sure that the user is informed about the need to connect
            machineObject.Log(LogLevel.Warning, "Awaiting GDB connection on port {0}", port);

            var connectedEvent = new System.Threading.ManualResetEvent(false);
            Action<Stream> listener = delegate
            {
                connectedEvent.Set();
            };

            if(!machineObject.AttachConnectionAcceptedListenerToGdbStub(port, listener))
            {
                throw new KeywordException($"No GDB server running on port {port}. Cannot await GDB connection");
            }
            connectedEvent.WaitOne();
            // If we fail here, we can't do anything - the stub might have disconnected
            machineObject.DetachConnectionAcceptedListenerFromGdbStub(port, listener);
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public string AllocateTemporaryFile()
        {
            return TemporaryFilesManager.Instance.GetTemporaryFile();
        }

        [RobotFrameworkKeyword]
        public string DownloadFile(string uri)
        {
            if(!Uri.TryCreate(uri, UriKind.Absolute, out var parsedUri))
            {
                throw new KeywordException($"Wrong URI format: {uri}");
            }

            var fileFetcher = EmulationManager.Instance.CurrentEmulation.FileFetcher;
            if(!fileFetcher.TryFetchFromUri(parsedUri, out var result))
            {
                throw new KeywordException("Couldn't download file from: {uri}");
            }

            return result;
        }

        [RobotFrameworkKeyword]
        public void RegisterFailingLogString(string pattern, bool treatAsRegex = false)
        {
            CheckLogTester();

            logTester.RegisterFailingString(pattern, treatAsRegex);
        }

        [RobotFrameworkKeyword]
        public void UnregisterFailingLogString(string pattern, bool treatAsRegex = false)
        {
            CheckLogTester();

            logTester.UnregisterFailingString(pattern, treatAsRegex);
        }

        [RobotFrameworkKeyword(replayMode: Replay.Always)]
        public void CreateLogTester(float timeout, bool? defaultPauseEmulation = null)
        {
            this.defaultPauseEmulation = defaultPauseEmulation.GetValueOrDefault();
            logTester = new LogTester(timeout);
            Logging.Logger.AddBackend(logTester, "Log Tester", true);
        }

        [RobotFrameworkKeyword]
        public string WaitForLogEntry(string pattern, float? timeout = null, bool keep = false, bool treatAsRegex = false,
            bool? pauseEmulation = null, LogLevel level = null)
        {
            CheckLogTester();

            var result = logTester.WaitForEntry(pattern, out var bufferedMessages, out var isFailingString, timeout, keep, treatAsRegex, pauseEmulation ?? defaultPauseEmulation, level);
            if(result == null)
            {
                // We must limit the length of the resulting string to Int32.MaxValue to avoid OutOfMemoryException.
                // We could do it accurately, but it doesn't seem worth here, because the goal is just to provide some extra context to the exception message.
                // We arbitrarily chose the number of messages to include here. In theory it could still throw during string.Join operation given very long messages,
                // but it's unlikely to happen given the value of Int32.MaxValue = 2,147,483,647.
                var logContextMessages = bufferedMessages.TakeLast(MaxLogContextPrintedOnException);
                var logMessages = string.Join("\n ", logContextMessages);
                throw new KeywordException($"Expected pattern \"{pattern}\" did not appear in the log\nLast {logContextMessages.Count()} buffered log messages are: \n {logMessages}");
            }
            if(isFailingString)
            {
                throw new InvalidOperationException($"Log tester failed!\n\nTest failing entry has been found in log:\n{result}");
            }
            return result;
        }

        [RobotFrameworkKeyword]
        public void ShouldNotBeInLog(String pattern, float? timeout = null, bool treatAsRegex = false, bool? pauseEmulation = null, LogLevel level = null)
        {
            CheckLogTester();

            // Passing `level` as a named argument causes a compiler crash in Mono 6.8.0.105+dfsg-3.4
            // from Debian
            var result = logTester.WaitForEntry(pattern, out var _, out var __, timeout, true, treatAsRegex, pauseEmulation ?? defaultPauseEmulation, level);
            if(result != null)
            {
                throw new KeywordException($"Unexpected line detected in the log: {result}");
            }
        }

        [RobotFrameworkKeyword]
        public void ClearLogTesterHistory()
        {
            CheckLogTester();
            logTester.ClearHistory();
        }

        [RobotFrameworkKeyword(replayMode: Replay.Never)]
        public void LogToFile(string filePath, bool flushAfterEveryWrite = false)
        {
            Logger.AddBackend(new FileBackend(filePath, flushAfterEveryWrite), "file", true);
        }

        [RobotFrameworkKeyword]
        public void OpenGUI()
        {
            Emulator.OpenGUI();
        }

        [RobotFrameworkKeyword]
        public void CloseGUI()
        {
            Emulator.CloseGUI();
        }

        [RobotFrameworkKeyword]
        public void EnableLoggingToCache()
        {
            if(cachedLogFilePath == null)
            {
                cachedLogFilePath = Path.Combine(
                        TemporaryFilesManager.Instance.EmulatorTemporaryPath,
                        "renode-robot.log");
                Logger.AddBackend(new FileBackend(cachedLogFilePath, false), CachedLogBackendName, true);
            }
        }

        [RobotFrameworkKeyword]
        public void SaveCachedLog(string filePath)
        {
            if(cachedLogFilePath == null)
            {
                throw new KeywordException($"Cannot save cached log, cached logging has not been enabled.");
            }

            (Logger.GetBackends()[CachedLogBackendName] as FileBackend).Flush();
            System.IO.File.Copy(cachedLogFilePath, filePath, true);
        }

        [RobotFrameworkKeyword]
        public void ClearCachedLog()
        {
            if(cachedLogFilePath != null)
            {
                Logger.RemoveBackend(Logger.GetBackends()[CachedLogBackendName]);
                System.IO.File.Delete(cachedLogFilePath);
                cachedLogFilePath = null;
                EnableLoggingToCache();
            }
        }

        private void CheckLogTester()
        {
            if(logTester == null)
            {
                throw new KeywordException("Log tester is not available. Create it with the `CreateLogTester` keyword");
            }
        }

        private void SetMonitorMachine(string machine)
        {
            if(!string.IsNullOrWhiteSpace(machine))
            {
                if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(machine, out var machobj))
                {
                    throw new KeywordException("Could not find machine named {0} in the emulation", machine);
                }
                monitor.Machine = machobj;
            }
        }

        private LogTester logTester;
        private string cachedLogFilePath;
        private bool defaultPauseEmulation;

        private readonly Dictionary<string, Savepoint> savepoints;

        private readonly Monitor monitor;

        private const string CachedLogBackendName = "cache";
        private const int MaxLogContextPrintedOnException = 1000;

        public enum ProviderType
        {
            Serialization = 0,
            Reexecution = 1,
        }

        private struct Savepoint
        {
            public Savepoint(string selectedMachine, string filename)
            {
                SelectedMachine = selectedMachine;
                Filename = filename;
            }

            public string SelectedMachine { get; }

            public string Filename { get; }
        }
    }
}