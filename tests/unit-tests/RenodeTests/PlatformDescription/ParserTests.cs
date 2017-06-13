//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Linq;
using Emul8.Core;
using Emul8.PlatformDescription;
using Emul8.PlatformDescription.Syntax;
using NUnit.Framework;
using Sprache;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class ParserTests
    {
        [Test]
        public void ShouldParseEmptyFile()
        {
            var source = string.Empty;

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());
        }

        [Test]
        public void ShouldParseUsingEntry()
        {
            var source = @"
using ""file.pl8""
using ""other_file.pl8""";
            
            var input = GetInputFromString(source);
            var result = Grammar.Description(input);
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var usingEntries = result.Value.Usings.Select(x => x.Path.Value);
            CollectionAssert.AreEquivalent(new[] { "file.pl8", "other_file.pl8" }, usingEntries);
        }

        [Test]
        public void ShouldParseSimpleEntry()
        {
            var source = @"
uart: UART";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.AreEqual("UART", (string)entry.Type);
        }

        [Test]
        public void ShouldParseEntryWithSimpleRegistrationInfo()
        {
            var source = @"
uart: @ sysbus";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.IsNull(entry.Type);
            Assert.AreEqual("sysbus", entry.RegistrationInfos.Single().Register.Value);
            Assert.IsNull(entry.RegistrationInfos.Single().RegistrationPoint);
        }

        [Test]
        public void ShouldParseEntryWithRangeRegistrationPoint()
        {
            var source = @"
uart: @ sysbus <0x2000A000, +0x1000>";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.IsNull(entry.Type);
            Assert.AreEqual("sysbus", entry.RegistrationInfos.Single().Register.Value);
            Assert.AreEqual(0x2000A000.By(0x1000), ((RangeValue)entry.RegistrationInfos.Single().RegistrationPoint).ToRange());
        }

        [Test]
        public void ShouldParseEntryWithStringRegistrationPoint()
        {
            var source = @"
uart: @ sysbus ""something""";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.IsNull(entry.Type);
            Assert.AreEqual("sysbus", entry.RegistrationInfos.Single().Register.Value);
            Assert.AreEqual("something", ((StringValue)entry.RegistrationInfos.Single().RegistrationPoint).Value);
        }

        [Test]
        public void ShouldParseEntryWithManyRegistrationPoints()
        {
            var source = @"
uart: @{ sysbus 0x100;
         sysbus 0x200}";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.IsNull(entry.Type);
            var registrationInfos = entry.RegistrationInfos.ToArray();
            Assert.AreEqual("sysbus", registrationInfos[0].Register.Value);
            Assert.AreEqual("0x100", ((NumericalValue)registrationInfos[0].RegistrationPoint).Value);

            Assert.AreEqual("sysbus", registrationInfos[1].Register.Value);
            Assert.AreEqual("0x200", ((NumericalValue)registrationInfos[1].RegistrationPoint).Value);
        }

        [Test]
        public void ShouldParseEntryWithOneAttribute()
        {
            var source = @"
uart:
    baudRate: BaudRate.B9600
";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            Assert.AreEqual("uart", entry.VariableName);
            Assert.IsNull(entry.Type);

            var attribute = (ConstructorOrPropertyAttribute)entry.Attributes.Single();
            Assert.AreEqual("baudRate", attribute.Name);
            Assert.AreEqual("B9600", ((EnumValue)attribute.Value).Value);
        }

        [Test]
        public void ShouldParseEntryWithTwoAttributes()
        {
            var source = @"
uart:
    friendlyName: ""some name""
    size: 0x1000
";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            var attributes = entry.Attributes;
            Assert.AreEqual(2, attributes.Count());
        }

        [Test]
        public void ShouldParseEntryWithAllAttributes()
        {
            var source = @"
uart:
    model: ""ABC666""
    numberOfBits: 32
    sleepTime: 0.01
    friendUart: otherUart
    range: <0x1000, +0x100>
";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            var attributes = entry.Attributes.Cast<ConstructorOrPropertyAttribute>().ToDictionary(x => x.Name, x => x.Value);
            Assert.AreEqual(5, attributes.Count);
            Assert.AreEqual("ABC666", ((StringValue)attributes["model"]).Value);
            Assert.AreEqual("32", ((NumericalValue)attributes["numberOfBits"]).Value);
            Assert.AreEqual("0.01", ((NumericalValue)attributes["sleepTime"]).Value);
            Assert.AreEqual("otherUart", ((ReferenceValue)attributes["friendUart"]).Value);
            Assert.AreEqual(0x1000.By(0x100), ((RangeValue)attributes["range"]).ToRange());
        }

        [Test]
        public void ShouldParseEntryWithSimpleIrqEntries()
        {
            var source = @"
uart:
    1 -> pic@2
    IRQ -> pic@3
    -> pic@4";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            var attributes = entry.Attributes.Cast<IrqAttribute>().ToArray();
            Assert.AreEqual(1, attributes[0].Sources.Single().Ends.Single().Number);
            Assert.AreEqual("pic", attributes[0].DestinationPeripheral.Reference.Value);
            Assert.AreEqual(2, attributes[0].Destinations.Single().Ends.Single().Number);
            Assert.AreEqual("IRQ", attributes[1].Sources.Single().Ends.Single().PropertyName);
            Assert.IsNull(attributes[2].Sources);
        }

        [Test]
        public void ShouldParseEntryWithMultiIrqEntries()
        {
            var source = @"
uart:
    [1-3, IRQ] -> pic @ [2-5]";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            var attributes = entry.Attributes.Cast<IrqAttribute>().ToArray();
            var flattenedSources = attributes[0].Sources.SelectMany(x => x.Ends).ToArray();
            var flattenedDestinations = attributes[0].Destinations.SelectMany(x => x.Ends).ToArray();
            Assert.AreEqual(1, flattenedSources[0].Number);
            Assert.AreEqual(2, flattenedSources[1].Number);
            Assert.AreEqual(3, flattenedSources[2].Number);
            Assert.AreEqual("IRQ", flattenedSources[3].PropertyName);

            Assert.AreEqual(2, flattenedDestinations[0].Number);
            Assert.AreEqual(3, flattenedDestinations[1].Number);
            Assert.AreEqual(4, flattenedDestinations[2].Number);
            Assert.AreEqual(5, flattenedDestinations[3].Number);
        }

        [Test]
        public void ShouldParseEntryWithLocalIrqReceiver()
        {
            var source = @"
uart:
    1 -> something#3@2";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entry = result.Value.Entries.Single();
            var attribute = entry.Attributes.OfType<IrqAttribute>().Single();
            Assert.AreEqual(1, attribute.Sources.Single().Ends.Single().Number);
            Assert.AreEqual("something", attribute.DestinationPeripheral.Reference.Value);
            Assert.AreEqual(3, attribute.DestinationPeripheral.LocalIndex);
            Assert.AreEqual(2, attribute.Destinations.Single().Ends.Single().Number);
        }

        [Test]
        public void ShouldParseInitAttributeWithOneLine()
        {
            var source = @"
uart:
    init:
        DoSomething 3
";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var onlyLine = ((InitAttribute)result.Value.Entries.Single().Attributes.Single()).Lines.Single();
            Assert.AreEqual("DoSomething 3", onlyLine);
        }

        [Test]
        public void ShouldParseInitAttributeWithMoreLines()
        {
            var source = @"
uart:
    init:
        Method1 a b
        Method2 true
        Method3";
            
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var lines = ((InitAttribute)result.Value.Entries.Single().Attributes.Single()).Lines.ToArray();
            Assert.AreEqual("Method1 a b", lines[0]);
            Assert.AreEqual("Method2 true", lines[1]);
            Assert.AreEqual("Method3", lines[2]);
        }

        [Test]
        public void ShouldParseObjectValue()
        {
            var source = @"
display: Display
    resolution: new Point
        x: 640
        y: 480
";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var objectValue = ((ObjectValue)((ConstructorOrPropertyAttribute)result.Value.Entries.Single().Attributes.Single()).Value);
            Assert.AreEqual("Point", (string)objectValue.TypeName);
            var attributes = objectValue.Attributes.Cast<ConstructorOrPropertyAttribute>().ToDictionary(x => x.Name, x => x.Value);
            Assert.AreEqual(2, attributes.Count);
            Assert.AreEqual("640", ((NumericalValue)attributes["x"]).Value);
            Assert.AreEqual("480", ((NumericalValue)attributes["y"]).Value);
        }

        [Test]
        public void ShouldParseTwoEntries()
        {
            var source = @"
uart1: UART @ sysbus <0x1000, +0x100>
    someProperty: someValue

uart2: UART @ sysbus <0x2000, +0x100>
    otherProperty: ""otherValue""
";
            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            Assert.AreEqual(2, result.Value.Entries.Count());
        }

        [Test]
        public void ShouldParseLocalAndNonLocalEntry()
        {
            var source = @"
peripheral: SomeHub
local other: Other";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var entries = result.Value.Entries.ToArray();
            Assert.IsFalse(entries[0].IsLocal);
            Assert.IsTrue(entries[1].IsLocal);
        }

        [Test]
        public void ShouldHandlePrefixedUsing()
        {
            var source = @"
using ""file1""
using ""file2"" prefixed ""prefix_""";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var usings = result.Value.Usings.ToArray();
            Assert.AreEqual("file1", usings[0].Path.Value);
            Assert.AreEqual("file2", usings[1].Path.Value);
            Assert.IsNull(usings[0].Prefix);
            Assert.AreEqual("prefix_", usings[1].Prefix);
        }

        [Test]
        public void ShouldParseExample()
        {
            var source = @"
screen: Display@graphicsCard1
    resolution: new Point { x: 5; y: 6 }
    refreshMode: Automatic
    model: ""SuperDisplay""
    -> ic@3
    init:
        DrawCircle 20 20
        DrawCircle 30 40

screen:
    init:
        DrawRect 40 50 1

screen:
    init:
        base init
        DrawRect 40 50 1

other: Display @ sysbus <0x0, +0x100> { refreshMode: Automatic; -> ic@3 }
";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());
        }

        [Test]
        public void ShouldParseTwoShortEntries()
        {
            var source = @"
uart: UART

uart: @sysbus <0x100, +0x100>
";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            Assert.AreEqual(2, result.Value.Entries.Count());
        }

        [Test]
        public void ShouldParseUsingAndEntry()
        {
            var source = @"
using ""other_file""

device: SomeDevice";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var usingEntry = result.Value.Usings.First();
            Assert.AreEqual("other_file", usingEntry.Path.Value);
            var entry = result.Value.Entries.First();
            Assert.AreEqual("device", entry.VariableName);
            Assert.AreEqual("SomeDevice", entry.Type.Value);
        }

        [Test]
        public void ShouldParseBool()
        {
            var source = @"
device: Something @ somewhere
    BoolProp: true
    BoolProp2: false
";

            var result = Grammar.Description(GetInputFromString(source));
            Assert.IsTrue(result.WasSuccessful, result.ToString());

            var values = result.Value.Entries.Single().Attributes.OfType<ConstructorOrPropertyAttribute>()
                                   .Select(x => x.Value).OfType<BoolValue>().ToArray();
            Assert.AreEqual(2, values.Length);
            Assert.AreEqual(true, values[0].Value);
            Assert.AreEqual(false, values[1].Value);
        }

        private static IInput GetInputFromString(string source)
        {
            var result = PreLexer.Process(source.Split(new[] { Environment.NewLine }, StringSplitOptions.None));
            var output = result.Aggregate((x, y) => x + Environment.NewLine + y);
            return new Input(output);
        }
    }
}
