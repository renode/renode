//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
namespace Antmicro.Renode.PlatformDescription
{
    public enum ParsingError
    {
        SyntaxError = 0,
        VariableNeverDeclared = 1,
        VariableAlreadyDeclared = 2,
        EmptyEntry = 3,
        TypeNotResolved = 4,
        NoUsableRegisterInterface = 5,
        TypeMismatch = 6,
        PropertyNotWritable = 7,
        WrongIrqArity = 8,
        PropertyOrCtorNameUsedMoreThanOnce = 9,
        PropertyDoesNotExist = 10,
        IrqDestinationDoesNotExist = 11,
        IrqDestinationIsNotIrqReceiver = 12,
        IrqSourceDoesNotExist = 13,
        IrqSourceIsNotNumberedGpioOutput = 14,
        AmbiguousDefaultIrqSource = 15,
        IrqSourceUsedMoreThanOnce = 16,
        DuplicateUsing = 17,
        NotLocalGpioReceiver = 18,
        MoreThanOneInitAttribute = 19,
        MissingReference = 20,
        NoCtorForRegistrationPoint = 21,
        AmbiguousCtorForRegistrationPoint = 22,
        EnumMismatch = 23,
        CreationOrderCycle = 24,
        NoCtor = 25,
        AmbiguousCtor = 26,
        InternalError = 27,
        AmbiguousRegistrationPointType = 28,
        InitSectionValidationError = 29,
        RecurringUsing = 30,
        InternalPrelexerError = 31,
        WrongIndent = 32,
        AliasWithoutRegistration = 33,
        AliasWithNoneRegistration = 34,
        CtorAttributesInNonCreatingEntry = 35,
        UsingFileNotFound = 36,
        AmbiguousRegistree = 37,
        ConstructionException = 38,
        RegistrationException = 39,
        PropertySettingException = 40,
        NameSettingException = 41,
        CastException = 42,
        IrqSourcePinDoesNotExist = 43,
        UninitializedSourceIrqObject = 44,
        RegistrationOrderCycle = 45,
        AliasedAndNormalArgumentName = 46,
        ResetSectionRegistrationError = 47,
        MoreThanOneResetAttribute = 48,
    }
}