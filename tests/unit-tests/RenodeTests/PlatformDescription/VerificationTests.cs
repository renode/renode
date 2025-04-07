//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.PlatformDescription;
using Antmicro.Renode.Utilities;

using NUnit.Framework;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class VerificationTests
    {
        [Test]
        public void ShouldProcessOneObject()
        {
            var source = @"
mock: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            ProcessSource(source);
        }

        [Test]
        public void ShouldProcessLateAttach()
        {
            var source = @"
mock: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral

mock: @sysbus <0x0, +0x100>";

            ProcessSource(source);
        }

        [Test]
        public void ShouldProcessWithoutTypeNameInFirstEntry()
        {
            var source = @"
mock: @sysbus <0x0, 0x1000>

mock: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            ProcessSource(source);
        }

        [Test]
        public void ShouldFailIfTypeIsSpecifiedSecondTime()
        {
            var source = @"
mock: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral

mock: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.VariableAlreadyDeclared, exception.Error);
        }

        [Test]
        public void ShouldFailOnEmptyEntry()
        {
            var source = @"
mock:";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.EmptyEntry, exception.Error);
        }

        [Test]
        public void ShouldFailOnNotExistingType()
        {
            var source = @"
someDevice: NotExistingType";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotResolved, exception.Error);
        }

        [Test]
        public void ShouldFailOnRegisteringNotIPeripheral()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockExternal @ sysbus
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoUsableRegisterInterface, exception.Error);
        }

        [Test]
        public void ShouldFailOnStringMismatch()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    Placeholder: 8
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonWritableProperty()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    Model: ""abc""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyNotWritable, exception.Error);
        }

        [Test]
        public void ShouldFailOnNumericEnumMismatch()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    EnumValue: ""abc""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingInlineType()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: new NotExistingType";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotResolved, exception.Error);
        }

        [Test]
        public void ShouldFailOnDoubleAttribute()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    EnumValue: One
    EnumValue: Two";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyOrCtorNameUsedMoreThanOnce, exception.Error);

        }

        [Test]
        public void ShouldFailOnNonExistingProperty()
        {
            var source = @"
external: Antmicro.Renode.UnitTests.Mocks.MockCPU
    NotExistingProperty: ""value""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldCheckTypeOfAReference()
        {
            var source = @"
one: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: two

two: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnIncorrectInlineObjectType()
        {
            var source = @"
one: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: new Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnIncorrectPropertyTypeInNestedInlineObject()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: new Antmicro.Renode.UnitTests.Mocks.MockCPU
        OtherCpu: new Antmicro.Renode.UnitTests.Mocks.MockCPU
            EnumValue: ""string""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNotExistingIrqDestination()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    IRQ -> receiver@0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqDestinationDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailOnIrqDestinationNotBeingIrqReceiver()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    Irq -> cpu@0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqDestinationIsNotIrqReceiver, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongIrqArity()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    [Irq] -> receiver@[0,1]
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.WrongIrqArity, exception.Error);

        }

        [Test]
        public void ShouldFailOnWrongIrqName()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    Something -> receiver@0
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailOnNumberIrqSourceNotBeingNumberedGpioOutput()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    [0-1] -> receiver@[0-1]
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceIsNotNumberedGpioOutput, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousDefaultIrq()
        {
            var source = @"
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSenderWithTwoInterrupts
    -> receiver@0

receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousDefaultIrqSource, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoIrqWhenUsingDefaultOne()
        {
            var source = @"
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU
    -> receiver@0
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailIfInterruptUsedSecondTimeInEntryAsSource()
        {
            var source = @"
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver
sender: Antmicro.Renode.UnitTests.Mocks.MockGPIOByNumberConnectorPeripheral
    2 -> receiver@6
    [0, 1-3, 7] -> receiver@[5-9]";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailIfDefaultInterruptUsedSecondTimeInEntry()
        {
            var source = @"
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    -> receiver@0
    -> receiver @1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailIfTheSameIrqUsedTwiceOnceAsDefault()
        {
            var source = @"
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver
sender: Antmicro.Renode.UnitTests.Mocks.MockIrqSender
    -> receiver@0
    Irq -> receiver @1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailWithMoreThanOneInitAttribute()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.MockCPU
    init:
        DoSomething
    init add:
        DoSomethingElse";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MoreThanOneInitAttribute, exception.Error);
        }

        [Test]
        public void ShouldFailOnMissingReference()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.MockCPU
    OtherCpu: unknown";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFailOnMissingReferenceInRegistrationPoint()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongReferenceRegistrationPointType()
        {
            var source = @"
regPoint: Antmicro.Renode.UnitTests.Mocks.MockCPU
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongObjectRegistrationPointType()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus new Antmicro.Renode.UnitTests.Mocks.MockCPU { Placeholder: ""abc"" }";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonConstruableRegistrationPoint()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ sysbus ""something""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtorForRegistrationPoint, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousConstructorForRegistrationPoint()
        {
            var source = @"
register: Antmicro.Renode.UnitTests.Mocks.AmbiguousRegister
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ register 1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtorForRegistrationPoint, exception.Error);
        }

        [Test]
        public void ShouldValidateObjectValueInCtorParameter()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    ctorParam: new NoSuchType";

            // note that this would also fail on not getting ctor, but it is important it will fail on unresolved type *earlier*

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotResolved, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoAvailableCtorInEntry()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    ctorParam: 3";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousCtorInEntry()
        {
            var source = @"
device: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
    value: 3";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoAvailableCtorInObjectValue()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
        other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
            x: 7";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousCtorInObjectValue()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
        other: new Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithDependency
            other: new Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral
                value: 4";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousRegistrationPoint()
        {
            var source = @"
register: Antmicro.Renode.UnitTests.Mocks.AmbiguousRegister
regPoint: Antmicro.Renode.UnitTests.Mocks.MockRegistrationPoint
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ register regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousRegistrationPointType, exception.Error);
        }

        [Test]
        public void ShouldFailOnAliasWithoutRegistrationInfo()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral as ""alias""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AliasWithoutRegistration, exception.Error);
        }

        [Test]
        public void ShouldFailOnAliasWithNoneRegistrationInfo()
        {
            var source = @"
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ none as ""alias""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AliasWithNoneRegistration, exception.Error);
        }

        [Test]
        public void ShouldFailWithConstructorAttributesWithNonCreatingEntry()
        {
            var source = @"
sysbus:
    x: 5";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.CtorAttributesInNonCreatingEntry, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousRegistree()
        {
            var source = @"
register: Antmicro.Renode.UnitTests.Mocks.AmbiguousRegister
peripheral: Antmicro.Renode.UnitTests.Mocks.EmptyPeripheral @ register 2.0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousRegistree, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonPeripheralRegister()
        {
            var source = @"
emptyIterestingType: Antmicro.Renode.UnitTests.Mocks.EmptyInterestingType
cpu: Antmicro.Renode.UnitTests.Mocks.MockCPU @ emptyIterestingType
";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.CastException, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingIrqSourcePin()
        {
            var source = @"
receiver: Antmicro.Renode.UnitTests.Mocks.MockReceiver
sender: Antmicro.Renode.UnitTests.Mocks.MockGPIOByNumberConnectorPeripheral
    gpios: 2
    2 -> receiver@1";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourcePinDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingConstructor()
        {
            var source = @"
p: Antmicro.Renode.UnitTests.Mocks.MockPeripheralWithProtectedConstructor @ sysbus 0x0
";
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
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

        private static void ProcessSource(string source)
        {
            var creationDriver = new CreationDriver(new Machine(), new FakeUsingResolver(), new FakeScriptHandler());
            creationDriver.ProcessDescription(source);
        }
    }
}