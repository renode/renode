//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.PlatformDescription;
using Antmicro.Renode.PlatformDescription.Syntax;
using Antmicro.Renode.Tests.UnitTests.Mocks;
using Antmicro.Renode.UnitTests.Mocks;
using Antmicro.Renode.Utilities;

using Moq;

using NUnit.Framework;

using static Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class MergeAndCreationTests
    {
        [Test]
        public void ShouldUpdateRegistrationPoint()
        {
            var source = @"
register1: Antmicro.Renode.UnitTests.Mocks.NullRegister @ sysbus <0, 100>
register2: Antmicro.Renode.UnitTests.Mocks.NullRegister @ sysbus new Antmicro.Renode.Peripherals.Bus.BusRangeRegistration { range: <100, +100> }
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ register1
cpu: @register2";

            ProcessSource(source);
            ICPU peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.register2.cpu", out peripheral));
            Assert.IsFalse(machine.TryGetByName("sysbus.register1.cpu", out peripheral));
        }

        [Test]
        public void ShouldCancelRegistration()
        {
            var source = @"
register: Antmicro.Renode.UnitTests.Mocks.NullRegister @ sysbus <0, 100>
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ register
cpu: @none";

            ProcessSource(source);
            ICPU peripheral;
            Assert.IsFalse(machine.TryGetByName("sysbus.register.cpu", out peripheral));
        }

        [Test]
        public void ShouldHandleRegistrationInReverseOrder()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ register
register: Antmicro.Renode.UnitTests.Mocks.NullRegister @ sysbus <0, 100>
";

            ProcessSource(source);
            ICPU peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.register.cpu", out peripheral));
        }

        [Test]
        public void ShouldHandleAlias()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus as ""otherName""";

            ProcessSource(source);
            ICPU peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.otherName", out peripheral));
            Assert.IsFalse(machine.TryGetByName("sysbus.cpu", out peripheral));
        }

        [Test]
        public void ShouldUpdateProperty()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: ""one""
    EnumValue: TwoStateEnum.Two

cpu:
    Placeholder: ""two""";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("two", mock.Placeholder);
            Assert.AreEqual(TwoStateEnum.Two, mock.EnumValue);
        }

        [Test]
        public void ShouldHandleEscapedOuoteInString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: ""one with \""escaped\"" quote\""""";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("one with \"escaped\" quote\"", mock.Placeholder);
        }

        [Test]
        public void ShouldHandleMultilineQuotedStringAsValue()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string'''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is\nmultiline\nstring", mock.Placeholder);
        }

        [Test]
        public void ShouldHandleMultipleMultilineQuotedStrings()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is a
multiline
string'''
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is another
multilineeee
stringgggg'''";

            ProcessSource(source);
            MockCPU mock1;
            MockCPU mock2;

            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock1));
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu2", out mock2));

            Assert.AreEqual("this is a\nmultiline\nstring", mock1.Placeholder);
            Assert.AreEqual("this is another\nmultilineeee\nstringgggg", mock2.Placeholder);
        }

        [Test]
        public void ShouldFailOnUnclosedMultipleMultilineQuotedStrings()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string'''
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string'''
cpu3: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
            var position = exception.Message.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)[1];
            Assert.AreEqual("At 11:17:", position);
        }

        [Test]
        public void ShouldFailOnUnclosedMultilineQuotedStringBetweenQuotedStrings()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string'''
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline
string
cpu3: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
multiline'''
string";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
            var position = exception.Message.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)[1];
            Assert.AreEqual("At 12:9:", position);
        }

        [Test, Ignore("Ignored")]
        public void ShouldHandleEscapedMultilineStringQuoteInSingleLineQuotedString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: ""one with \''' escaped quote""";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("one with ''' escaped quote", mock.Placeholder);
        }

        [Test, Ignore("Ignored")]
        public void ShouldHandleMultipleEscapeCharsInMultilineString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''one with escaped quote\\'''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("one with escaped quote\\", mock.Placeholder);
        }


        [Test]
        public void ShouldHandleMultilineQuotedStringInOneLine()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is single line'''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is single line", mock.Placeholder);
        }

        [Test]
        public void ShouldFailOnMultilineQuotedStringInUsing()
        {
            var source = @"
using '''this is
multiline
string '''";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldHandleEscapedQuoteInMultilineString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is \''' single line'''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is ''' single line", mock.Placeholder);
        }

        [Test]
        public void ShouldHandleEscapedUnescapedSingleQuoteCharInMultilineString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: ''' this is string with ' and '' '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual(" this is string with ' and '' ", mock.Placeholder);
        }

        [Test]
        public void ShouldFailOnAnyStringAfterClosedMultilineString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is
not a single line ''' xx";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
            var position = exception.Message.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)[1];
            Assert.AreEqual("At 4:23:", position);
        }

        [Test]
        public void ShouldFailOnMultipleMultilineStringSignsInOneLine()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is \''' ''' ''' '''
not a single line '''";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
            var position = exception.Message.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)[1];
            Assert.AreEqual("At 3:37:", position);
        }

        [Test]
        public void ShouldHandleMultipleEscapedMultilineStringSignsInOneLine()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is \''' \''' \''' \'''
not a single line '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is ''' ''' ''' '''\nnot a single line ", mock.Placeholder);
        }

        [Test]
        public void ShouldFailOnUnclosedMultilineString()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is ";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
            var position = exception.Message.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)[1];
            Assert.AreEqual("At 3:17:", position);
        }

        [Test]
        public void ShouldHandleEscapedMultilineStringSignInNewLine()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is 
\'''
not a single line '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is \n\'''\nnot a single line ", mock.Placeholder);
        }

        [Test]
        public void ShouldHandleEscapedMultilineStringSignAtTheEndOfALine()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is \'''
not a single line '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual("this is \'''\nnot a single line ", mock.Placeholder);
        }

        [Test]
        public void ShouldNotTreatDoubleSlashInMultilineStringAsComment()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: ''' // this is //
// not
a comment // neither is this
or //this
or// this
or this // '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual(" // this is //\n// not\na comment // neither is this\nor //this\nor// this\nor this // ", mock.Placeholder);
        }

        [Test, Ignore("Ignored")]
        public void ShouldHandleMultipleBackslashesAsEscapingCharacters()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    Placeholder: '''this is \\\'''
not a single line '''";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual(@"this is \\\'''
not a single line ", mock.Placeholder);
        }

        [Test]
        public void ShouldHandleNoneInProperty()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    EnumValue: TwoStateEnum.Two

cpu:
    EnumValue: none";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual(TwoStateEnum.One, mock.EnumValue);
        }

        [Test]
        public void ShouldHandleEmptyNumericalValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithNumericalAttrubute @ sysbus  <0, 1>
    mockInt: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralWithNumericalAttrubute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(int), mockPeripheral.MockInt);
        }

        [Test]
        public void ShouldHandleEmptyStringValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithStringAttribute @ sysbus  <0, 1>
    mockString: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralWithStringAttribute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(string), mockPeripheral.MockString);
        }

        [Test]
        public void ShouldHandleEmptyEnumValue()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    EnumValue: empty";

            ProcessSource(source);
            MockCPU mock;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out mock));
            Assert.AreEqual(default(TwoStateEnum), mock.EnumValue);
        }

        [Test]
        public void ShouldHandleEmptyRangeValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithRangeAttribute @ sysbus  <0, 1>
    mockRange: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralWithRangeAttribute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(Core.Range), mockPeripheral.MockRange);
        }

        [Test]
        public void ShouldHandleEmptyObjectValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithObjectAttribute @ sysbus  <0, 1>
    mockObject: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralWithObjectAttribute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(Object), mockPeripheral.MockObject);
        }

        [Test]
        public void ShouldHandleEmptyListValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntList: empty";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(List<int>), mockPeripheral.MockIntList);
        }

        [Test]
        public void ShouldHandleEmptyArrayValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntArray: empty";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(int[]), mockPeripheral.MockIntArray);
        }

        [Test]
        public void ShouldHandleEmptyBoolValue()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithBoolAttribute @ sysbus  <0, 1>
    mockBool: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralWithBoolAttribute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(bool), mockPeripheral.MockBool);
        }

        [Test]
        public void ShouldHandleEmptyReferenceAttribute()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralUsingReferenceAttribute @ sysbus <0, 1>
    mockReference: empty";

            ProcessSource(source);
            Tests.UnitTests.Mocks.MockPeripheralUsingReferenceAttribute mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));
            Assert.AreEqual(default(Antmicro.Renode.Peripherals.IPeripheral), mockPeripheral.MockReference);
        }

        [Test]
        public void ShouldFailOnEmptyKeywordAsType()
        {
            var source = @"
mockPeripheral: empty @ sysbus <0, 1>
    value: 0";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldFailOnEmptyKeywordAsRegistrationDestination()
        {
            var source = @"
mockPeripheral:  Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ empty <0, 1>
    value: 0";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldFailOnEmptyKeywordAsParameterName()
        {
            var source = @"
mockPeripheral:  Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0, 1>
    empty: 0";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldFailOnEmptyKeywordAsUsingParameter()
        {
            var source = @"using empty";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldHandleNoneInCtorParam()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0, 1>
    value: 1

peripheral:
    value: none";

            ProcessSource(source);
            EmptyPeripheral peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.peripheral", out peripheral));
            Assert.AreEqual(1, peripheral.Counter);
        }

        [Test]
        public void ShouldUpdateSingleInterrupt()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender @ sysbus <0, 1>
    [Irq] -> receiver@[0]
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <1, 2>
sender:
    Irq -> receiver@1";

            ProcessSource(source);
            MockIrqSender sender;
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out sender));
            Assert.AreEqual(1, sender.Irq.Endpoints[0].Number);
        }

        [Test]
        public void ShouldHandleEmptyListOfIntegers()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntList: []";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            Assert.IsNotNull(mockPeripheral.MockIntList);
            CollectionAssert.IsEmpty(mockPeripheral.MockIntList);
        }

        [Test]
        public void ShouldHandleListOfIntegers()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntList: [2, 1, 37]";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            CollectionAssert.AreEqual(new[] { 2, 1, 37 }, mockPeripheral.MockIntList);
        }

        [Test]
        public void ShouldHandleArrayOfIntegers()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntArray: [1, 2, 34]";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            CollectionAssert.AreEqual(new[] { 1, 2, 34 }, mockPeripheral.MockIntArray);
        }

        [Test]
        public void ShouldHandleListOfStrings()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockStringList: [""a"", ""b"", ""c""]";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            CollectionAssert.AreEqual(new[] { "a", "b", "c" }, mockPeripheral.MockStringList);
        }

        [Test]
        public void ShouldFailOnTypeMismatchInList()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntList: [1, ""b"", 3]";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnTypeMismatchInArray()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntArray: [1, ""b"", 3]";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldReplaceList()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockIntList: [1, 2, 3]

mockPeripheral:
    mockIntList: [4, 5]";

            ProcessSource(source);
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            CollectionAssert.AreEqual(new[] { 4, 5 }, mockPeripheral.MockIntList);
        }

        [Test]
        public void ShouldHandleListOfReferences()
        {
            var source = @"
cpu1: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
cpu2: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus

mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithCollectionAttributes @ sysbus  <0, 1>
    mockCpuList: [cpu1, cpu2]";

            ProcessSource(source);
            MockCPU cpu1, cpu2;
            MockPeripheralWithCollectionAttributes mockPeripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu1", out cpu1));
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu2", out cpu2));
            Assert.IsTrue(machine.TryGetByName("sysbus.mockPeripheral", out mockPeripheral));

            Assert.AreEqual(2, mockPeripheral.MockCpuList.Count);
            Assert.AreSame(cpu1, mockPeripheral.MockCpuList[0]);
            Assert.AreSame(cpu2, mockPeripheral.MockCpuList[1]);
        }

        [Test]
        public void ShouldHandleManyMultiplexedMultiDestinationInterrupts()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockGPIOByNumberConnectorPeripheral @ sysbus <3, 4>
    gpios: 2
    [0, Irq] -> receiver@[1-2] | receiver2@[3-4] | receiver3@[5-6]
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <0, 1>
receiver2: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <1, 2>
receiver3: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <2, 3>";

            ProcessSource(source);
            MockGPIOByNumberConnectorPeripheral sender;
            MockReceiver receiver, receiver2, receiver3;
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out sender));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver", out receiver));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver2", out receiver2));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver3", out receiver3));

            Assert.AreEqual(3, sender.Irq.Endpoints.Count);
            Assert.AreEqual(2, sender.Irq.Endpoints[0].Number);
            Assert.AreEqual(4, sender.Irq.Endpoints[1].Number);
            Assert.AreEqual(6, sender.Irq.Endpoints[2].Number);

            Assert.AreEqual(receiver, sender.Irq.Endpoints[0].Receiver);
            Assert.AreEqual(receiver2, sender.Irq.Endpoints[1].Receiver);
            Assert.AreEqual(receiver3, sender.Irq.Endpoints[2].Receiver);
        }

        [Test]
        public void ShouldCancelIrqConnection()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender @ sysbus <0, 1> { [Irq] -> receiver@[0] }
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <1, 2>
sender:
    Irq -> none";

            ProcessSource(source);
            MockIrqSender sender;
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out sender));
            Assert.IsFalse(sender.Irq.IsConnected);
        }

        [Test]
        public void ShouldUpdateDefaultIrq()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender @ sysbus <0, 1>
    [Irq] -> receiver@[0]
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus <1, 2>
sender:
    -> receiver@2";

            ProcessSource(source);
            MockIrqSender sender;
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out sender));
            Assert.AreEqual(2, sender.Irq.Endpoints[0].Number);
        }

        [Test]
        public void ShouldUpdateMultiInterrupts()
        {
            var a = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockGPIOByNumberConnectorPeripheral @ sysbus <0, 1>
    gpios: 64
    [0-2, 3-5, Irq, OtherIrq] -> receiver@[0-7] | receiver@[8-15]
    6 -> receiver2@7
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus<1, 2>
receiver2: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus<2, 3>";

            var source = @"
using ""A""

sender:
    [Irq, 3-4] -> receiver2@[0-2]
    6 -> receiver@16
    [7-8] -> receiver@[17-18]
";

            ProcessSource(source, a);
            MockGPIOByNumberConnectorPeripheral sender;
            MockReceiver receiver1, receiver2;
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out sender));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver", out receiver1));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver2", out receiver2));

            Assert.AreEqual(0, sender.Irq.Endpoints[0].Number);
            Assert.AreEqual(receiver2, sender.Irq.Endpoints[0].Receiver);
            Assert.AreEqual(7, sender.OtherIrq.Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.OtherIrq.Endpoints[0].Receiver);
            Assert.AreEqual(0, sender.Connections[0].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[0].Endpoints[0].Receiver);
            Assert.AreEqual(1, sender.Connections[1].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[1].Endpoints[0].Receiver);
            Assert.AreEqual(2, sender.Connections[2].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[2].Endpoints[0].Receiver);
            Assert.AreEqual(1, sender.Connections[3].Endpoints[0].Number);
            Assert.AreEqual(receiver2, sender.Connections[3].Endpoints[0].Receiver);
            Assert.AreEqual(2, sender.Connections[4].Endpoints[0].Number);
            Assert.AreEqual(receiver2, sender.Connections[4].Endpoints[0].Receiver);
            Assert.AreEqual(5, sender.Connections[5].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[5].Endpoints[0].Receiver);
            Assert.AreEqual(16, sender.Connections[6].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[6].Endpoints[0].Receiver);
            Assert.AreEqual(17, sender.Connections[7].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[7].Endpoints[0].Receiver);
            Assert.AreEqual(18, sender.Connections[8].Endpoints[0].Number);
            Assert.AreEqual(receiver1, sender.Connections[8].Endpoints[0].Receiver);
        }

        [Test]
        public void ShouldCombineIfInterruptUsedSecondTimeInEntryAsDestination()
        {
            var source = @"
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver @ sysbus
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSenderWithTwoInterrupts @ sysbus
    Irq -> receiver@0
    AnotherIrq -> receiver@0";

            ProcessSource(source);
            Assert.IsTrue(machine.TryGetByName("sysbus.sender", out MockIrqSenderWithTwoInterrupts sender));
            Assert.IsTrue(machine.TryGetByName("sysbus.receiver", out MockReceiver receiver));

            Assert.AreEqual(0, sender.Irq.Endpoints[0].Number);
            Assert.AreEqual(1, sender.AnotherIrq.Endpoints[0].Number);
            Assert.IsInstanceOf(typeof(CombinedInput), sender.Irq.Endpoints[0].Receiver);
            var combiner = (CombinedInput)sender.Irq.Endpoints[0].Receiver;
            Assert.AreEqual(0, combiner.OutputLine.Endpoints[0].Number);
            Assert.AreEqual(receiver, combiner.OutputLine.Endpoints[0].Receiver);
            Assert.AreEqual(combiner, sender.AnotherIrq.Endpoints[0].Receiver);
        }

        [Test]
        public void ShouldFailOnUsingAlreadyRegisteredPeripheralsName()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            var peripheral = new EmptyPeripheral();
            machine.SystemBus.Register(peripheral, new Antmicro.Renode.Peripherals.Bus.BusRangeRegistration(0.To(1)));
            machine.SetLocalName(peripheral, "peripheral");

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.VariableAlreadyDeclared, exception.Error);
        }

        [Test]
        public void ShouldTakeAlreadyRegisteredPeripheralsAsVariables()
        {
            var source = @"
newCpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus 2
    OtherCpu: cpu";

            var cpu = new MockCPU(machine);
            machine.SystemBus.Register(cpu, new CPURegistrationPoint(1));
            machine.SetLocalName(cpu, "cpu");

            ProcessSource(source);
            MockCPU otherMockCpu;
            Assert.IsTrue(machine.TryGetByName("sysbus.newCpu", out otherMockCpu));
            Assert.AreEqual(cpu, otherMockCpu.OtherCpu);
        }

        [Test]
        public void ShouldNotDetectCycleInPerCoreRegistration()
        {
            var source = @"
core1_nvic: IRQControllers.NVIC @ sysbus new Bus.BusPointRegistration { 
    address: 0xE000E000;
    cpu: cpu1
}

core2_nvic: IRQControllers.NVIC @ sysbus new Bus.BusPointRegistration {
    address: 0xE000E000;
    cpu: cpu2
}

cpu1: CPU.CortexM @ sysbus
    cpuType: ""cortex-m0""
    nvic: core1_nvic

cpu2: CPU.CortexM @ sysbus
    cpuType: ""cortex-m0""
    nvic: core2_nvic";

            ProcessSource(source);
        }

        [Test]
        public void ShouldNotDetectCycleInSignalConnection()
        {
            var source = @"
clint: IRQControllers.CoreLevelInterruptor @ {
        sysbus new Bus.BusPointRegistration { address: 0x002000000; cpu: cpu_rv }
    }
    [0,1] -> cpu_rv@[3,7]
    frequency: 10000000

cpu_rv: CPU.RiscV32 @ sysbus
    cpuType: ""rv32ima""
    timeProvider: clint";

            ProcessSource(source);
        }

        [Test]
        public void ShouldReplaceInit()
        {
            var source = @"
peri: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0, 1>
    init:
        Increment

peri:
    init:
        Increment
        Increment";

            ProcessSource(source);
            scriptHandlerMock.Verify(x => x.Execute(It.IsAny<IScriptable>(), new[] { "Increment", "Increment" }, It.IsAny<Action<string>>()));
        }

        [Test]
        public void ShouldAddInit()
        {
            var source = @"
peri: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    init:
        Increment

peri:
    init add:
        Increment
        Increment";


            ProcessSource(source);
            scriptHandlerMock.Verify(x => x.Execute(It.IsAny<IScriptable>(), new[] { "Increment", "Increment", "Increment" }, It.IsAny<Action<string>>()));
        }

        [Test]
        public void ShouldUpdateSysbusInit()
        {
            var source = @"
sysbus:
    init:
        WriteByte 0 1";

            ProcessSource(source);
            scriptHandlerMock.Verify(x => x.Execute(It.IsAny<IScriptable>(), new[] { "WriteByte 0 1" }, It.IsAny<Action<string>>()));
        }

        [Test]
        public void ShouldFailOnNotValidatedInit()
        {
            var a = @"
peri: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    init:
        Increment
        Increment";

            var source = @"
using ""A""

peri:
    init:
        Increment";

            var errorMessage = "Invalid init section";
            scriptHandlerMock.Setup(x => x.ValidateInit(It.IsAny<IScriptable>(), out errorMessage)).Returns(false);
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a));
            Assert.AreEqual(ParsingError.InitSectionValidationError, exception.Error);
        }

        [Test]
        public void ShouldReplaceReset()
        {
            var source = @"
peri: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0, 1>
    reset:
        Increment

peri:
    reset:
        Increment
        Increment";

            ProcessSource(source);
            scriptHandlerMock.Verify(x => x.RegisterReset(It.IsAny<IScriptable>(), new[] { "Increment", "Increment" }, It.IsAny<Action<string>>()));
        }

        [Test]
        public void ShouldAddReset()
        {
            var source = @"
peri: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    reset:
        Increment

peri:
    reset add:
        Increment
        Increment";


            ProcessSource(source);
            scriptHandlerMock.Verify(x => x.RegisterReset(It.IsAny<IScriptable>(), new[] { "Increment", "Increment", "Increment" }, It.IsAny<Action<string>>()));
        }

        [Test]
        public void ShouldFindCyclicDependency()
        {
            var source = @"
peri1: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
        other: peri2

peri3: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri4

peri4: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri1

peri2: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri3
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.CreationOrderCycle, exception.Error);
        }

        [Test]
        public void ShouldFindCyclicReferenceToItself()
        {
            var source = @"
peri: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.CreationOrderCycle, exception.Error);
        }

        [Test]
        public void ShouldFindCyclicReferenceBetweenFiles()
        {
            var a = @"
peri1: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri3
peri3: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
";

            var source = @"
using ""A""
peri2: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: peri1

peri3:
    other: peri2";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source, a));
            Assert.AreEqual(ParsingError.CreationOrderCycle, exception.Error);
        }

        [Test]
        public void ShouldSetPropertyOfInlineObject()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ sysbus
    OtherCpu: new Antmicro.Renode.UnitTests.Mocks.MockCPU
        OtherCpu: new Antmicro.Renode.UnitTests.Mocks.MockCPU
            Placeholder: ""something""";

            ProcessSource(source);
            MockCPU cpu;
            Assert.IsTrue(machine.TryGetByName("sysbus.cpu", out cpu));
            Assert.AreEqual("something", ((cpu.OtherCpu as MockCPU).OtherCpu as MockCPU).Placeholder);
        }

        [Test]
        public void ShouldRegisterPeripheralWithManyRegistrationPoints()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @{
    sysbus <0x100, +0x10>;
    sysbus <0x200, +0x20>} as ""alias""
";
            ProcessSource(source);
            EmptyPeripheral peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.alias", out peripheral));
            var ranges = machine.GetPeripheralRegistrationPoints(machine.SystemBus, peripheral).OfType<Antmicro.Renode.Peripherals.Bus.BusRangeRegistration>().Select(x => x.Range).ToArray();
            Assert.AreEqual(0x100.By(0x10), ranges[0]);
            Assert.AreEqual(0x200.By(0x20), ranges[1]);
            Assert.AreEqual(2, ranges.Length);
        }

        [Test]
        public void ShouldFailOnNonExistingReferenceInCtorAttribute()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: nonExististing";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldProcessEntryDependantOnSysbus()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: sysbus";

            ProcessSource(source);
        }

        [Test]
        public void ShouldProcessEntryDependantOnSysbusWithUpdateEntry()
        {
            var source = @"
sysbus:
    init:
        Method

peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: sysbus";

            ProcessSource(source);
        }

        [Test]
        public void ShouldCatchExceptionOnEntryConstruction()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    throwException: true";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.ConstructionException, exception.Error);
        }

        [Test]
        public void ShouldCatchExceptionOnObjectValueConstruction()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
        throwException: true";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.ConstructionException, exception.Error);
        }

        [Test]
        public void ShouldCatchExceptionOnPropertySetting()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    ThrowingProperty: 1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertySettingException, exception.Error);
        }

        [Test]
        public void ShouldCatchExceptionOnRegistration()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ {
    sysbus <0x100, +0x100>;
    sysbus <0x150, +0x100>    
}";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.RegistrationException, exception.Error);
        }

        [Test]
        public void ShouldHandleNameConflict()
        {
            var source = @"
p1: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0x100, +0x50>
p2: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus <0x200, +0x50> as ""p1""
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NameSettingException, exception.Error);
        }

        [Test]
        public void ShouldProcessRepeatedRegistration()
        {
            var source = @"
mockRegister1: Antmicro.Renode.UnitTests.Mocks.MockRegister @ sysbus 0x0
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ {
    mockRegister1;
    mockRegister2
}
mockRegister2: Antmicro.Renode.UnitTests.Mocks.MockRegister @ sysbus 0x100
";
            ProcessSource(source);

            ICPU peripheral;
            Assert.IsTrue(machine.TryGetByName("sysbus.mockRegister1.cpu", out peripheral));
            Assert.IsTrue(machine.TryGetByName("sysbus.mockRegister2.cpu", out peripheral));
        }

        [Test]
        public void ShouldFailRegistrationOnUnregisteredParent()
        {
            var source = @"
unregisteredParent: Antmicro.Renode.UnitTests.Mocks.MockRegister

cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ unregisteredParent
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.RegistrationException, exception.Error);
        }

        [Test]
        public void ShouldProcessValidEnum()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute @ sysbus <0, 1>
    mockEnum: MockEnum.ValidValue
";

            ProcessSource(source);
            var result = machine.TryGetByName("sysbus.mockPeripheral", out Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute mockPeripheral);
            Assert.IsTrue(result);
            Assert.AreEqual(MockEnum.ValidValue, mockPeripheral.MockEnumValue);
        }

        [Test]
        public void ShouldProcessValidShorthandEnum()
        {
            var source = @"
mockPeripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute @ sysbus <0, 1>
    mockEnum: .ValidValue
";

            ProcessSource(source);
            var result = machine.TryGetByName("sysbus.mockPeripheral", out Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute mockPeripheral);
            Assert.IsTrue(result);
            Assert.AreEqual(MockEnum.ValidValue, mockPeripheral.MockEnumValue);
        }

        [Test]
        public void ShouldFailOnInvalidEnum()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute
    mockEnum: MockEnum.InvalidValue
";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldProcessValidIntAsEnum()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute @ sysbus <0, 1>
    mockEnum: 1
";
            ProcessSource(source);
            Assert.IsTrue(machine.TryGetByName("sysbus.peripheral", out Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute mockPeripheral));
            Assert.AreEqual(MockEnum.ValidValue, mockPeripheral.MockEnumValue);
        }

        [Test]
        public void ShouldFailOnInvalidIntToEnumCast()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute
    mockEnum: 2
";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnInvalidIntToEnumWithAttributeCast()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute @ sysbus <0, 1>
    mockEnumWithAttribute: MockEnumWithAttribute.InvalidValue
";
            //ProcessSource(source);
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldProcessCastOfAnyIntToEnumWithAttribute()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute @ sysbus <0, 1>
    mockEnumWithAttribute: 2
";
            ProcessSource(source);
            Assert.IsTrue(machine.TryGetByName("sysbus.peripheral", out Tests.UnitTests.Mocks.MockPeripheralWithEnumAttribute mockPeripheral));
            Assert.AreEqual((MockEnumWithAttribute)2, mockPeripheral.MockEnumWithAttributeValue);
        }

        [Test]
        public void ShouldFailOnAssignmentOfMachineTypeAttribute()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MachineTestPeripheral @ sysbus <0, 1>
    mach: empty
    machine: empty
";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldNotFailOnAssignmentToAttributeWithMachineParameterNameThatIsNotMachine()
        {
            var source = @"
peripheral: Antmicro.Renode.Tests.UnitTests.Mocks.MachineTestPeripheral @ sysbus <0, 1>
    machine: empty
";
            Assert.DoesNotThrow(() => ProcessSource(source));
        }

        [Test]
        public void ShouldAcceptPreviousRegistrationPoint()
        {
            var source = @"
mock: @ sysbus
mock: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            Assert.DoesNotThrow(() => ProcessSource(source));
        }

        [Test]
        public void ShouldRejectPreviousIncompatibleRegistrationPoint()
        {
            var source = @"
mock: @ sysbus <0, 1>
mock: Antmicro.Renode.UnitTests.Mocks.MockCPU";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtorForRegistrationPoint, exception.Error);
        }

        [OneTimeSetUp]
        public void Init()
        {
            if(!Misc.TryGetRootDirectory(out var rootDir))
            {
                throw new ArgumentException("Couldn't get root directory.");
            }
            TypeManager.Instance.Scan(rootDir);
        }

        [SetUp]
        public void SetUp()
        {
            machine = new Machine();
            EmulationManager.Instance.CurrentEmulation.AddMachine(machine, "machine");
            scriptHandlerMock = new Mock<IScriptHandler>();
            string nullMessage = null;
            scriptHandlerMock.Setup(x => x.ValidateInit(It.IsAny<IScriptable>(), out nullMessage)).Returns(true);
        }

        [TearDown]
        public void TearDown()
        {
            var currentEmulation = EmulationManager.Instance.CurrentEmulation;
            currentEmulation.RemoveMachine(machine);
        }

        private void ProcessSource(params string[] sources)
        {
            var letters = Enumerable.Range(0, sources.Length - 1).Select(x => (char)('A' + x)).ToArray();
            var usingResolver = new FakeUsingResolver();
            for(var i = 1; i < sources.Length; i++)
            {
                usingResolver.With(letters[i - 1].ToString(), sources[i]);
            }
            var creationDriver = new CreationDriver(machine, usingResolver, scriptHandlerMock.Object);
            creationDriver.ProcessDescription(sources[0]);
        }

        private Mock<IScriptHandler> scriptHandlerMock;
        private Machine machine;
    }
}