//
// Copyright (c) 2010-2017 Antmicro
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
        // This method accepts array of strings that is later
        // concatenated using single space and parsed by the monitor.
        //
        // Using array instead of a single string allows us to
        // split long commands into several lines using (...)
        // notation in robot script; otherwise it would be impossible
        // as there is no option to split a single parameter.
        public string ExecuteCommand(string[] commandFragments)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.Clear();
            var command = string.Join(" ", commandFragments);
            if(!monitor.Parse(command))
            {
                throw new KeywordException("Could not execute command '{0}': {1}", command, interaction.GetError());
            }

            return interaction.GetContents();
        }

        [RobotFrameworkKeyword]
        public string ExecuteScript(string path)
        {
            var interaction = monitor.Interaction as CommandInteractionWrapper;
            interaction.Clear();

            if(!monitor.TryExecuteScript(path))
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
            switch(action)
            {
                case HotSpotAction.None:
                    // do nothing
                    break;
                case HotSpotAction.Pause:
                    EmulationManager.Instance.CurrentEmulation.PauseAll();
                    EmulationManager.Instance.CurrentEmulation.StartAll();
                    break;
                case HotSpotAction.Serialize:
                    var fileName = TemporaryFilesManager.Instance.GetTemporaryFile();
                    EmulationManager.Instance.Save(fileName);
                    EmulationManager.Instance.Load(fileName);
                    EmulationManager.Instance.CurrentEmulation.StartAll();
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

        private readonly Monitor monitor;
    }
}

