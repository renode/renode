//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Antmicro.Renode.Core;
using Antmicro.Renode.UserInterface;
using Antmicro.Renode.Utilities;
using NUnit.Framework;

namespace Antmicro.Renode.UnitTests
{
    public class ReplLoadingTest
    {
        [TestFixtureSetUp]
        public void FixtureInit()
        {
            monitor = new Monitor { Interaction = new DummyCommandInteraction(true) };
            var context = ObjectCreator.Instance.OpenContext();
            context.RegisterSurrogate(typeof(Monitor), monitor);
        }

        [Test, TestCaseSource("GetRepls")]
        //This test verifies only platforms/cpus/*repl, as board repl files are sometimes just a part of a bigger setup and cannot be loaded separately.
        public void LoadAllRepls(string repl)
        {
            // the `init:` section in .repl files requires having a machine context in Monitor to execute commands,
            // therefore we load it via `monitor.Parse`
            monitor.Parse("mach create");
            Assert.IsTrue(monitor.Parse($"machine LoadPlatformDescription @{repl}"), $"Failed to load script {repl}");
            Assert.IsFalse(((DummyCommandInteraction)monitor.Interaction).ErrorDetected);
            monitor.Parse("Clear");
        }

        private static IEnumerable<string> GetRepls()
        {
            if(!Misc.TryGetRootDirectory(out var rootDirectory))
            {
                throw new ArgumentException("Couldn't get root directory.");
            }
            TypeManager.Instance.Scan(rootDirectory);
            return Directory.GetFiles(rootDirectory, "*.repl", SearchOption.AllDirectories).Where(x => x.Contains(Path.Combine("platforms", "cpus")));
        }

        private Monitor monitor;
    }
}
