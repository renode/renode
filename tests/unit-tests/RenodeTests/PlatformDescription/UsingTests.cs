//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.PlatformDescription;
using Antmicro.Renode.UnitTests.Mocks;

using NUnit.Framework;

using static Antmicro.Renode.PlatformDescription.UserInterface.PlatformDescriptionMachineExtensions;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class UsingTests
    {
        [Test]
        public void ShouldFindVariableFromUsing()
        {
            var a = @"
cpu1: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            var source = @"
using ""A""
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            ProcessSource(null, source, a);
        }

        [Test]
        public void ShouldNotFindLocalVariableFromUsing()
        {
            var a = @"
local cpu1: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            var source = @"
using ""A""
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(null, source, a));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFindVariableFromNestedUsing()
        {
            var source = @"
using ""A""
cpu3: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: cpu2";

            var a = @"
using ""B""
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            var b = @"
cpu1: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            ProcessSource(null, source, a, b);
        }

        [Test]
        public void ShouldAllowReverseVariableDependency()
        {
            var source = @"
using ""A""
otherCpu: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            var a = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: otherCpu";

            ProcessSource(null, source, a);
        }

        [Test]
        public void ShouldFindPrefixedVariable()
        {
            var source = @"
using ""A"" prefixed ""a_""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: a_cpu";

            var a = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            ProcessSource(null, source, a);
        }

        [Test]
        public void ShouldFindNestedPrefixedVariable()
        {
            var source = @"
using ""A"" prefixed ""a_""
using ""B""
someCpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: a_b_cpu

oneMoreCpu: Antmicro.Renode.UnitTests.Mocks.MockCPU { OtherCpu: cpu }
";

            var a = @"
using ""B"" prefixed ""b_""";

            var b = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            ProcessSource(null, source, a, b);
        }

        [Test]
        public void ShouldFollowAttributeOverrideOrder0()
        {
            var source = @"
using ""A""
using ""B""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus 0x0
    Placeholder: ""set by source first""

cpu:
    Placeholder: ""set by source second""
";

            var a = @"
cpu:
    Placeholder: ""set by A""
";

            var b = @"
using ""C""
cpu:
    Placeholder: ""set by B""
";

            var c = @"
cpu:
    Placeholder: ""set by C""
";

            var machine = new Machine();
            ProcessSource(machine, source, a, b, c);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("set by source second", mock.Placeholder);
        }

        [Test]
        public void ShouldFollowAttributeOverrideOrder1()
        {
            var source = @"
using ""A""
using ""B""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
";

            var a = @"
cpu:
    Placeholder: ""set by A first""
cpu:
    Placeholder: ""set by A second""
";

            var b = @"
using ""C""
cpu:
    Placeholder: ""set by B first""
cpu:
    Placeholder: ""set by B second""
";

            var c = @"
cpu:
    Placeholder: ""set by C first""
cpu:
    Placeholder: ""set by C second""
";

            var machine = new Machine();
            ProcessSource(machine, source, a, b, c);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("set by B second", mock.Placeholder);
        }

        [Test]
        public void ShouldFollowAttributeOverrideOrder2()
        {
            var source = @"
using ""A""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus 0x0
";

            var a = @"
using ""B""
cpu:
    Placeholder: ""set by A""
";

            var b = @"
cpu:
    Placeholder: ""set by B""
";

            var machine = new Machine();
            ProcessSource(machine, source, a, b);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("set by A", mock.Placeholder);
        }

        [Test]
        public void ShouldFollowAttributeOverrideOrder3()
        {
            var source = @"
using ""A""
using ""B""
using ""C""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
";

            var a = @"
cpu:
    Placeholder: ""set by A first""
cpu:
    Placeholder: ""set by A second""
";

            var b = @"
cpu:
    Placeholder: ""set by B first""
cpu:
    Placeholder: ""set by B second""
";
            var c = @"
using ""A"";
";

            var machine = new Machine();
            ProcessSource(machine, source, a, b, c);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("set by A second", mock.Placeholder);
        }

        [Test]
        public void ShouldFollowAttributeOverrideOrder4()
        {
            var source = @"
using ""A""
using ""B""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
";

            var a = @"
cpu:
    Placeholder: ""set by A first""
cpu:
    Placeholder: ""set by A second""
";

            var b = @"
using ""A""
cpu:
    Placeholder: ""set by B first""
cpu:
    Placeholder: ""set by B second""
";

            var machine = new Machine();
            ProcessSource(machine, source, a, b);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("set by B second", mock.Placeholder);
        }

        [Test]
        public void ShouldFailOnDuplicateUsingEntry()
        {
            var source = @"
using ""A""
using ""B""
using ""A""
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
";

            var a = @"
cpu:
    Placeholder: ""set by A first""
cpu:
    Placeholder: ""set by A second""
";

            var b = @"
cpu:
    Placeholder: ""set by B first""
cpu:
    Placeholder: ""set by B second""
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(null, source, a, b));
            Assert.AreEqual(ParsingError.DuplicateUsing, exception.Error);
        }

        [Test]
        public void ShouldHandleIrqDestinationOnPrefixing()
        {
            var a = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockReceiver
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    Irq -> cpu@0";

            var source = @"
using ""A"" prefixed ""sth_""";

            ProcessSource(null, source, a);
        }

        [Test]
        public void ShouldFailOnRecurringUsings()
        {
            var b = @"
using ""A""
p: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var a = @"
using ""B""
p2: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var source = @"
using ""B""
p3: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(null, source, a, b));
            Assert.AreEqual(ParsingError.RecurringUsing, exception.Error);
        }

        [Test]
        public void ShouldFailOnDirectlyRecurringUsings()
        {
            var a = @"
using ""A""
p: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var source = @"
using ""A""
p2: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(null, source, a));
            Assert.AreEqual(ParsingError.RecurringUsing, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingUsingFile()
        {
            var source = @"
using ""A""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(null, source));
            Assert.AreEqual(ParsingError.UsingFileNotFound, exception.Error);
        }

#if PLATFORM_WINDOWS
        [Test]
        public void ShouldHandleAbsolutePath()
        {
            // On Windows, both \ and / should work as path component separators in the path to be resolved
            // and the returned path should always use the preferred \ separator
            Assert.AreEqual(@"C:\tmp\platform.repl", ResolvePath(@"C:\tmp\platform.repl", @"C:\tmp\includer.repl"));
            Assert.AreEqual(@"C:\tmp\platform.repl", ResolvePath(@"C:/tmp/platform.repl", @"C:\tmp\includer.repl"));
        }

        [Test]
        public void ShouldHandleRelativePathInSameDirectory()
        {
            Assert.AreEqual(@"C:\tmp\platform.repl", ResolvePath(@".\platform.repl", @"C:\tmp\includer.repl"));
            Assert.AreEqual(@"C:\tmp\platform.repl", ResolvePath(@"./platform.repl", @"C:\tmp\includer.repl"));
        }

        [Test]
        public void ShouldHandleRelativePathInParentDirectory()
        {
            Assert.AreEqual(@"C:\abc\platform.repl", ResolvePath(@"..\abc\platform.repl", @"C:\tmp\includer.repl"));
            Assert.AreEqual(@"C:\abc\platform.repl", ResolvePath(@"../abc/platform.repl", @"C:\tmp\includer.repl"));
        }
#else
        [Test]
        public void ShouldHandleAbsolutePath()
        {
            Assert.AreEqual("/tmp/platform.repl", ResolvePath("/tmp/platform.repl", "/tmp/includer.repl"));
        }

        [Test]
        public void ShouldHandleRelativePathInSameDirectory()
        {
            Assert.AreEqual("/tmp/platform.repl", ResolvePath("./platform.repl", "/tmp/includer.repl"));
        }

        [Test]
        public void ShouldHandleRelativePathInParentDirectory()
        {
            Assert.AreEqual("/abc/platform.repl", ResolvePath("../abc/platform.repl", "/tmp/includer.repl"));
        }

        [Test]
        public void BackslashShouldNotBePathSeparatorOnUnix()
        {
            // Backslashes are a valid filename character on Unix
            Assert.AreEqual(@"/tmp/plat\form.repl", ResolvePath(@"./plat\form.repl", "/tmp/includer.repl"));
        }
#endif

        [SetUp]
        public void SetUp()
        {
            resolver = new UsingResolver(Enumerable.Empty<string>());
        }

        private static void ProcessSource(Machine machine, params string[] sources)
        {
            var letters = Enumerable.Range(0, sources.Length - 1).Select(x => (char)('A' + x)).ToArray();
            var usingResolver = new FakeUsingResolver();
            for(var i = 1; i < sources.Length; i++)
            {
                usingResolver.With(letters[i - 1].ToString(), sources[i]);
            }
            var creationDriver = new CreationDriver(machine ?? new Machine(), usingResolver, new FakeScriptHandler());
            creationDriver.ProcessDescription(sources[0]);
        }

        private string ResolvePath(string path, string includingPath)
        {
            return resolver.Resolve(path, includingPath);
        }

        private UsingResolver resolver;
    }
}