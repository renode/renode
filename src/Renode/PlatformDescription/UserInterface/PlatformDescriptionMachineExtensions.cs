//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.IO;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.UserInterface;

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

        private static CreationDriver PrepareDriver(Machine machine)
        {
            var monitor = ObjectCreator.Instance.GetSurrogate<Monitor>();
            var usingResolver = new UsingResolver(monitor.CurrentPathPrefixes);
            var monitorScriptHandler = new MonitorScriptHandler(machine, monitor);
            var driver = new CreationDriver(machine, usingResolver, monitorScriptHandler);
            return driver;
        }

        public class UsingResolver : IUsingResolver
        {
            public UsingResolver(IEnumerable<string> pathPrefixes)
            {
                this.pathPrefixes = pathPrefixes;
            }

            public string Resolve(string argument, string includingFile)
            {
                // Handle absolute paths
                if(Path.IsPathRooted(argument))
                {
                    return Path.GetFullPath(argument); // No existence check, but resolve "a/../b" and the like
                }

                // Handle relative paths
                var components = argument.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                var firstComponent = components.FirstOrDefault();
                if(firstComponent == "." || firstComponent == "..")
                {
                    var includingFileDirectory = Path.GetDirectoryName(includingFile);
                    var relativePath = Path.Combine(includingFileDirectory, argument);
                    return Path.GetFullPath(relativePath); // No existence check, the path was resolved
                }

                foreach(var prefix in pathPrefixes)
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
    }
}