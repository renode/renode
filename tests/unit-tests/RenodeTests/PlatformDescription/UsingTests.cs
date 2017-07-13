//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Linq;
using Emul8.Core;
using Antmicro.Renode.PlatformDescription;
using NUnit.Framework;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class UsingTests
    {
        [Test]
        public void ShouldFindVariableFromUsing()
        {
            var a = @"
cpu1: UnitTests.Mocks.MockCPU";

            var source = @"
using ""A""
cpu2: UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            ProcessSource(source, a);
        }

        [Test]
        public void ShouldNotFindLocalVariableFromUsing()
        {
            var a = @"
local cpu1: UnitTests.Mocks.MockCPU";

            var source = @"
using ""A""
cpu2: UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFindVariableFromNestedUsing()
        {
            var source = @"
using ""A""
cpu3: UnitTests.Mocks.MockCPU
    OtherCpu: cpu2";

            var a = @"
using ""B""
cpu2: UnitTests.Mocks.MockCPU
    OtherCpu: cpu1";

            var b = @"
cpu1: UnitTests.Mocks.MockCPU";

            ProcessSource(source, a, b);
        }

        [Test]
        public void ShouldFailOnReverseVariableDependency()
        {
            var source = @"
using ""A""
otherCpu: UnitTests.Mocks.MockCPU";

            var a = @"
cpu: UnitTests.Mocks.MockCPU
    OtherCpu: otherCpu";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFindPrefixedVariable()
        {
            var source = @"
using ""A"" prefixed ""a_""
cpu: UnitTests.Mocks.MockCPU
    OtherCpu: a_cpu";

            var a = @"
cpu: UnitTests.Mocks.MockCPU";

            ProcessSource(source, a);
        }

        [Test]
        public void ShouldFindNestedPrefixedVariable()
        {
            var source = @"
using ""A"" prefixed ""a_""
using ""B""
someCpu: UnitTests.Mocks.MockCPU
    OtherCpu: a_b_cpu

oneMoreCpu: UnitTests.Mocks.MockCPU { OtherCpu: cpu }
";

            var a = @"
using ""B"" prefixed ""b_""";

            var b = @"
cpu: UnitTests.Mocks.MockCPU";

            ProcessSource(source, a, b);
        }

        [Test]
        public void ShouldHandleIrqDestinationOnPrefixing()
        {
            var a = @"
cpu: UnitTests.Mocks.MockReceiver
sender: UnitTests.Mocks.MockIrqSender
    Irq -> cpu@0";

            var source = @"
using ""A"" prefixed ""sth_""";

            ProcessSource(source, a);
        }

        [Test]
        public void ShouldFailOnRecurringUsings()
        {
            var b = @"
using ""A""
p: UnitTests.Mocks.EmptyPeripheral";

            var a = @"
using ""B""
p2: UnitTests.Mocks.EmptyPeripheral";

            var source = @"
using ""B""
p3: UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a, b));
            Assert.AreEqual(ParsingError.RecurringUsing, exception.Error);
        }

        [Test]
        public void ShouldFailOnDirectlyRecurringUsings()
        {
            var a = @"
using ""A""
p: UnitTests.Mocks.EmptyPeripheral";

            var source = @"
using ""A""
p2: UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a));
            Assert.AreEqual(ParsingError.RecurringUsing, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingUsingFile()
        {
            var source = @"
using ""A""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.UsingFileNotFound, exception.Error);
        }

        private static void ProcessSource(params string[] sources)
        {
            var letters = Enumerable.Range(0, sources.Length - 1).Select(x => (char)('A' + x)).ToArray();
            var usingResolver = new FakeUsingResolver();
            for(var i = 1; i < sources.Length; i++)
            {
                usingResolver.With(letters[i - 1].ToString(), sources[i]);
            }
            var creationDriver = new CreationDriver(new Machine(), usingResolver, new FakeInitHandler());
        	creationDriver.ProcessDescription(sources[0]);
        }
    }
}
