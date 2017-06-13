//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System.Collections.Generic;
using System.IO;
using Emul8.Core;
using Emul8.UserInterface;

namespace Antmicro.Renode.PlatformDescription.UserInterface
{
    public static class PlatformDescriptionMachineExtensions
    {
        public static void LoadPlatformDescription(this Machine machine, string platformDescriptionFile)
        {
            PrepareDriver(machine).ProcessFile(platformDescriptionFile);
        }

        public static void LoadPlatformDescriptionFromString(this Machine machine, string platformDescription)
        {
            PrepareDriver(machine).ProcessDescription(platformDescription);
        }

        public class UsingResolver : IUsingResolver
        {
            public UsingResolver(IEnumerable<string> pathPrefixes)
            {
                this.pathPrefixes = pathPrefixes;
            }

            public string Resolve(string argument)
            {
                foreach (var prefix in pathPrefixes)
                {
                    var fullPath = Path.GetFullPath(Path.Combine(prefix, argument));
                    if(File.Exists(fullPath))
                    {
                        return fullPath;
                    }
                }
                return null;
            }

            private readonly IEnumerable<string> pathPrefixes;
        }

        private static CreationDriver PrepareDriver(Machine machine)
        {
            var monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
            var usingResolver = new UsingResolver(monitor.CurrentPathPrefixes);
            var monitorInitHandler = new MonitorInitHandler(machine, monitor);
            var driver = new CreationDriver(machine, usingResolver, monitorInitHandler);
            return driver;
        }
    }
}
