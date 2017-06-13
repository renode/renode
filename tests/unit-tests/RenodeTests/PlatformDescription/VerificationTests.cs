//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Emul8.Core;
using Emul8.Exceptions;
using Emul8.PlatformDescription;
using Emul8.Utilities;
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
mock: UnitTests.Mocks.EmptyPeripheral";

            ProcessSource(source);
        }

        [Test]
        public void ShouldProcessLateAttach()
        {
            var source = @"
mock: UnitTests.Mocks.EmptyPeripheral

mock: @sysbus <0x0, +0x100>";

            ProcessSource(source);
        }

        [Test]
        public void ShouldNotProcessWithoutTypeNameInFirstEntry()
        {
            var source = @"
mock: @sysbus <0x0, 0x1000>

mock: UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotSpecifiedInFirstVariableUse, exception.Error);
        }

        [Test]
        public void ShouldFailIfTypeIsSpecifiedSecondTime()
        {
            var source = @"
mock: UnitTests.Mocks.EmptyPeripheral

mock: UnitTests.Mocks.EmptyPeripheral";

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
external: Emul8.UnitTests.Mocks.MockExternal @ sysbus
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoUsableRegisterInterface, exception.Error);
        }

        [Test]
        public void ShouldFailOnStringMismatch()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    Placeholder: 8
";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonWritableProperty()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    Model: ""abc""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyNotWritable, exception.Error);
        }

        [Test]
        public void ShouldFailOnNumericEnumMismatch()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    EnumValue: ""abc""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonExistingInlineType()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    OtherCpu: new NotExistingType";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotResolved, exception.Error);
        }

        [Test]
        public void ShouldFailOnDoubleAttribute()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    EnumValue: One
    EnumValue: Two";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyOrCtorNameUsedMoreThanOnce, exception.Error);

        }

        [Test]
        public void ShouldFailOnNonExistingProperty()
        {
            var source = @"
external: UnitTests.Mocks.MockCPU
    NotExistingProperty: ""value""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.PropertyDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldCheckTypeOfAReference()
        {
            var source = @"
one: UnitTests.Mocks.MockCPU
    OtherCpu: two

two: UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnIncorrectInlineObjectType()
        {
            var source = @"
one: UnitTests.Mocks.MockCPU
    OtherCpu: new UnitTests.Mocks.EmptyPeripheral";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnIncorrectPropertyTypeInNestedInlineObject()
        {
            var source = @"
cpu: UnitTests.Mocks.MockCPU
    OtherCpu: new UnitTests.Mocks.MockCPU
        OtherCpu: new UnitTests.Mocks.MockCPU
            EnumValue: ""string""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNotExistingIrqDestination()
        {
            var source = @"
sender: UnitTests.Mocks.MockIrqSender
    IRQ -> receiver@0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqDestinationDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailOnIrqDestinationNotBeingIrqReceiver()
        {
            var source = @"
cpu: UnitTests.Mocks.MockCPU
sender: UnitTests.Mocks.MockIrqSender
    Irq -> cpu@0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqDestinationIsNotIrqReceiver, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongIrqArity()
        {
            var source = @"
sender: UnitTests.Mocks.MockIrqSender
    [Irq] -> receiver@[0,1]
receiver: UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.WrongIrqArity, exception.Error);

        }

        [Test]
        public void ShouldFailOnWrongIrqName()
        {
            var source = @"
sender: UnitTests.Mocks.MockIrqSender
    Something -> receiver@0
receiver: UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailOnNumberIrqSourceNotBeingNumberedGpioOutput()
        {
            var source = @"
sender: UnitTests.Mocks.MockIrqSender
    [0-1] -> receiver@[0-1]
receiver: UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceIsNotNumberedGpioOutput, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousDefaultIrq()
        {
            var source = @"
sender: Emul8.UnitTests.Mocks.MockIrqSenderWithTwoInterrupts
    -> receiver@0

receiver: UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousDefaultIrqSource, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoIrqWhenUsingDefaultOne()
        {
            var source = @"
cpu: UnitTests.Mocks.MockCPU
    -> receiver@0
receiver: UnitTests.Mocks.MockReceiver";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceDoesNotExist, exception.Error);
        }

        [Test]
        public void ShouldFailIfInterruptUsedSecondTimeInEntryAsSource()
        {
            var source = @"
receiver: UnitTests.Mocks.MockReceiver
sender: UnitTests.Mocks.MockGPIOByNumberConnectorPeripheral
    2 -> receiver@6
    [0, 1-3, 7] -> receiver@[5-9]";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailIfDefaultInterruptUsedSecondTimeInEntry()
        {
            var source = @"
receiver: UnitTests.Mocks.MockReceiver
sender: UnitTests.Mocks.MockIrqSender
    -> receiver@0
    -> receiver @1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailIfTheSameIrqUsedTwiceOnceAsDefault()
        {
            var source = @"
receiver: UnitTests.Mocks.MockReceiver
sender: UnitTests.Mocks.MockIrqSender
    -> receiver@0
    Irq -> receiver @1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqSourceUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailIfInterruptUsedSecondTimeInEntryAsDestination()
        {
            var source = @"
receiver: UnitTests.Mocks.MockReceiver
sender: Emul8.UnitTests.Mocks.MockIrqSenderWithTwoInterrupts
    Irq -> receiver@0
    AnotherIrq -> receiver@0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.IrqDestinationUsedMoreThanOnce, exception.Error);
        }

        [Test]
        public void ShouldFailWithMoreThanOneInitAttribute()
        {
            var source = @"
device: UnitTests.Mocks.MockCPU
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
device: UnitTests.Mocks.MockCPU
    OtherCpu: unknown";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFailOnMissingReferenceInRegistrationPoint()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral @ sysbus regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.MissingReference, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongReferenceRegistrationPointType()
        {
            var source = @"
regPoint: UnitTests.Mocks.MockCPU
device: UnitTests.Mocks.EmptyPeripheral @ sysbus regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnWrongObjectRegistrationPointType()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral @ sysbus new UnitTests.Mocks.MockCPU { Placeholder: ""abc"" }";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeMismatch, exception.Error);
        }

        [Test]
        public void ShouldFailOnNonConstruableRegistrationPoint()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral @ sysbus ""something""";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtorForRegistrationPoint, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousConstructorForRegistrationPoint()
        {
            var source = @"
register: Emul8.UnitTests.Mocks.AmbiguousRegister
device: UnitTests.Mocks.EmptyPeripheral @ register 1";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtorForRegistrationPoint, exception.Error);
        }

        [Test]
        public void ShouldValidateObjectValueInCtorParameter()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral
    ctorParam: new NoSuchType";

            // note that this would also fail on not getting ctor, but it is important it will fail on unresolved type *earlier*

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.TypeNotResolved, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoAvailableCtorInEntry()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral
    ctorParam: 3";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousCtorInEntry()
        {
            var source = @"
device: UnitTests.Mocks.EmptyPeripheral
    value: 3";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnNoAvailableCtorInObjectValue()
        {
            var source = @"
peripheral: Emul8.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Emul8.UnitTests.Mocks.MockPeripheralWithDependency
        other: new Emul8.UnitTests.Mocks.MockPeripheralWithDependency
            x: 7";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtor, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousCtorInObjectValue()
        {
            var source = @"
peripheral: Emul8.UnitTests.Mocks.MockPeripheralWithDependency
    other: new Emul8.UnitTests.Mocks.MockPeripheralWithDependency
        other: new Emul8.UnitTests.Mocks.MockPeripheralWithDependency
            other: new UnitTests.Mocks.EmptyPeripheral
                value: 4";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousCtor, exception.Error);
        }

        [Test]
        public void ShouldNotAcceptNullRegistrationPointWhenRealOneIsNecessary()
        {
            var source = @"
peripheral: UnitTests.Mocks.EmptyPeripheral @ sysbus";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.NoCtorForRegistrationPoint, exception.Error);
        }

        [Test]
        public void ShouldFailOnAmbiguousRegistrationPoint()
        {
            var source = @"
register: Emul8.UnitTests.Mocks.AmbiguousRegister
regPoint: Emul8.UnitTests.Mocks.MockRegistrationPoint
peripheral: UnitTests.Mocks.EmptyPeripheral @ register regPoint";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousRegistrationPointType, exception.Error);
        }

        [Test]
        public void ShouldFailOnAliasWithoutRegistrationInfo()
        {
            var source = @"
peripheral: UnitTests.Mocks.EmptyPeripheral as ""alias""";
            
            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AliasWithoutRegistration, exception.Error);
        }

        [Test]
        public void ShouldFailOnAliasWithNoneRegistrationInfo()
        {
            var source = @"
peripheral: UnitTests.Mocks.EmptyPeripheral @ none as ""alias""";

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
register: Emul8.UnitTests.Mocks.AmbiguousRegister
peripheral: UnitTests.Mocks.EmptyPeripheral @ register 2.0";

            var exception = Assert.Throws<ParsingException>(() => ProcessSource(source));
            Assert.AreEqual(ParsingError.AmbiguousRegistree, exception.Error);
        }

        [TestFixtureSetUp]
        public void Init()
        {
            string emul8Dir;
            if(!Misc.TryGetEmul8Directory(out emul8Dir))
            {
                throw new ArgumentException("Couldn't get Emul8 directory.");
            }
            TypeManager.Instance.Scan(emul8Dir);
        }

        private static void ProcessSource(string source)
        {
            var creationDriver = new CreationDriver(new Machine(), new FakeUsingResolver(), new FakeInitHandler());
            creationDriver.ProcessDescription(source);
        }
    }
}
