//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;

namespace Antmicro.Renode.RobotFramework
{
    public class Recorder
    {
        static Recorder()
        {
            Instance = new Recorder();
        }

        public static Recorder Instance { get; private set; }

        public void RecordEvent(string name, string[] args)
        {
            events.Add(new Event { Name = name, Arguments = args });
        }

        public void SaveCurrentState(string name)
        {
            // this is to allow overwriting when running tests with -n argument
            savedStates[name] = new List<Event>(events);
        }

        public bool TryGetState(string name, out List<Event> events)
        {
            return savedStates.TryGetValue(name, out events);
        }

        public void ClearEvents()
        {
            events.Clear();
        }

        private Recorder()
        {
            events = new List<Event>();
            savedStates = new Dictionary<string, List<Event>>();
        }

        private readonly List<Event> events;
        private readonly Dictionary<string, List<Event>> savedStates;

        public struct Event
        {
            public string Name { get; set; }
            public string[] Arguments { get; set; }
        }
    }
}
