//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using Antmicro.Renode.Core;
using Antmicro.Renode.UserInterface;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    internal class RenodeKeywords : IRobotFrameworkKeywordProvider
    {
        public RenodeKeywords()
        {
            monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
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
        }

        [RobotFrameworkKeyword]
        public void StartEmulation()
        {
            EmulationManager.Instance.CurrentEmulation.StartAll();
        }

        [RobotFrameworkKeyword]
        public string ExecuteCommand(string command, string machine = null)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.Clear();
            if(!string.IsNullOrWhiteSpace(machine))
            {
                if(!EmulationManager.Instance.CurrentEmulation.TryGetMachineByName(machine, out var machobj))
                {
                    throw new KeywordException("Could not find machine named {0} in the emulation", machine);

                }
                monitor.Machine = machobj;
            }

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

        [RobotFrameworkKeyword]
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

        [RobotFrameworkKeyword]
        public void Provides(string state)
        {
            Recorder.Instance.SaveCurrentState(state);
        }

        [RobotFrameworkKeyword]
        public void Requires(string state)
        {
            List<Recorder.Event> events;
            if(!Recorder.Instance.TryGetState(state, out events))
            {
                throw new KeywordException("Required state {0} not found.", state);
            }
            ResetEmulation();
            var robotFrontendEngine = (RobotFrameworkEngine)ObjectCreator.Instance.GetSurrogate(typeof(RobotFrameworkEngine));
            foreach(var e in events)
            {
                robotFrontendEngine.ExecuteKeyword(e.Name, e.Arguments);
            }
        }

        [RobotFrameworkKeyword]
        public void WaitForPause(int timeout)
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

            try
            {
                masterTimeSource.BlockHook += callback;

                if(!mre.WaitOne(timeout * 1000))
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
        public string AllocateTemporaryFile()
        {
            return TemporaryFilesManager.Instance.GetTemporaryFile();
        }

        private readonly Monitor monitor;
    }
}

