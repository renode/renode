//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Sprache;

// all elements of parse tree has to be located in this namespace
// because SyntaxTreeHelper only visits objects of types located there
namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public static class Grammar
    {
        // note that all fields here are created in the file order, i.e. as written
        // due to that, depending on a field that is below can lead to a unexpected NullReferenceException
        // in such case use Parsers.Ref <-- see Sprache's xml docs

        public static readonly HashSet<string> Keywords = new HashSet<string>();

        public static readonly Parser<char> Separator = Parse.Char(';').Token();

        public static readonly Parser<char> AtSign = Parse.Char('@').Token();

        public static readonly Parser<char> MultiplexSign = Parse.Char('|').Token();

        public static readonly Parser<char> Colon = Parse.Char(':').Token().Named("colon");

        public static readonly Parser<char> Comma = Parse.Char(',').Token();

        public static readonly Parser<char> PlusSign = Parse.Char('+').Token();

        public static readonly Parser<char> OpeningChevron = Parse.Char('<').Token();

        public static readonly Parser<char> ClosingChevron = Parse.Char('>').Token();

        public static readonly Parser<char> OpeningBrace = Parse.Char('{').Token();

        public static readonly Parser<char> ClosingBrace = Parse.Char('}').Token();

        public static readonly Parser<char> OpeningSquareBracket = Parse.Char('[').Token();

        public static readonly Parser<char> ClosingSquareBracket = Parse.Char(']').Token();

        public static readonly Parser<char> Minus = Parse.Char('-').Token();

        //not set as a token, as it may be used inside strings where we want to preserve spaces
        public static readonly Parser<char> QuotationMark = Parse.Char('"');

        public static readonly Parser<string> MultiQuotationMark = Parse.String("'''").Text();

        public static readonly Parser<char> EscapeCharacter = Parse.Char('\\');

        public static readonly Parser<char> NumberSeparator = Parse.Char('_');

        public static readonly Parser<string> RightArrow = Parse.String("->").Text().Token().Named("arrow");

        public static readonly Parser<string> HexadecimalPrefix = Parse.String("0x").Text();

        public static readonly Parser<string> DigitSequence =
            (from digits in Parse.Number
             from digitsContinuation in NumberSeparator.Then(_ => Parse.Number).Many().Select(x => String.Join(String.Empty, x))
             select digits + digitsContinuation);

        public static readonly Parser<long> DecimalLong = DigitSequence.Select(x => long.Parse(x)).Token().Named("decimal number");

        public static readonly Parser<ulong> DecimalUnsignedLong = DigitSequence.Select(x => ulong.Parse(x)).Token().Named("decimal non-negative number");

        public static readonly Parser<char> HexadecimalDigit = Parse.Chars("0123456789ABCDEFabcdef");

        public static readonly Parser<string> HexadecimalDigitSequence =
            (from hexadecimalDigits in HexadecimalDigit.AtLeastOnce().Text()
             from hexadecimalDigitsContinuation in NumberSeparator.Then(_ => HexadecimalDigit.AtLeastOnce().Text()).Many().Select(x => String.Join(String.Empty, x))
             select hexadecimalDigits + hexadecimalDigitsContinuation);

        public static readonly Parser<ulong> HexadecimalUnsignedLong =
            HexadecimalPrefix.Then(x => HexadecimalDigitSequence.Select(y => ulong.Parse(y, System.Globalization.NumberStyles.HexNumber))).Token().Named("hexadecimal number");

        public static readonly Parser<uint> HexadecimalUnsignedInt = HexadecimalUnsignedLong.Select(x => (uint)x);
        public static readonly Parser<int> HexadecimalInt = HexadecimalUnsignedLong.Select(x => (int)x);

        public static readonly Parser<int> DecimalInt = DecimalLong.Select(x => (int)x);
        public static readonly Parser<uint> DecimalUnsignedInt = DecimalUnsignedLong.Select(x => (uint)x);

        public static readonly Parser<string> HexadecimalNumberWithSign =
            (from sign in Minus.Optional()
             from prefix in HexadecimalPrefix
             from digits in HexadecimalDigitSequence
             select (sign.IsDefined ? "-" : "") + prefix + digits).Token().Named("hexadecimal number");

        public static readonly Parser<string> DecimalNumberWithSign =
            (from sign in Minus.Optional()
             from integerPart in DigitSequence
             from fractionalPart in (Parse.Char('.').Then(x => Parse.Number.Select(y => x + y))).Optional()
             select (sign.IsDefined ? "-" : "") + integerPart + fractionalPart.GetOrElse("")).Token().Named("decimal number");

        public static readonly Parser<string> Number = HexadecimalNumberWithSign.Or(DecimalNumberWithSign);

        public static readonly Parser<string> GeneralIdentifier =
            (from startingLetter in Parse.Letter.Once().Text()
             from rest in Parse.LetterOrDigit.Or(Parse.Char('_')).Many().Text()
             select startingLetter + rest).Token();

        public static readonly Parser<string> UsingKeyword = MakeKeyword("using");

        public static readonly Parser<string> NewKeyword = MakeKeyword("new");

        public static readonly Parser<string> AsKeyword = MakeKeyword("as");

        public static readonly Parser<string> InitKeyword = MakeKeyword("init");

        public static readonly Parser<string> ResetKeyword = MakeKeyword("reset");

        public static readonly Parser<string> LocalKeyword = MakeKeyword("local");

        public static readonly Parser<string> PrefixedKeyword = MakeKeyword("prefixed");

        public static readonly Parser<bool> TrueKeyword = MakeKeyword("true", true);

        public static readonly Parser<bool> FalseKeyword = MakeKeyword("false", false);

        public static readonly Parser<Value> NoneKeyword = MakeKeyword("none", (Value)null);

        public static readonly Parser<EmptyValue> EmptyKeyword = MakeKeyword("empty", EmptyValue.Instance);

        public static readonly Parser<string> Identifier = GeneralIdentifier.Named("identifier").Where(x => !Keywords.Contains(x));

        public static readonly Parser<StringWithPosition> TypeName =
            (from first in Identifier
             from rest in Parse.Char('.').Then(x => Identifier).XMany()
             select new StringWithPosition(rest.Aggregate(first, (x, y) => x + '.' + y))).Positioned();

        public static readonly Parser<char> QuotedStringElement = EscapeCharacter.Then(x => QuotationMark.XOr(EscapeCharacter)).XOr(Parse.CharExcept('"'));

        public static readonly Parser<string> MultiQuotedStringElement = EscapeCharacter.Then(x => MultiQuotationMark).XOr(Parse.AnyChar.Except(MultiQuotationMark).Select(x => x.ToString()));

        public static readonly Parser<string> SingleLineQuotedString =
            (from openingQuote in QuotationMark
             from content in QuotedStringElement.Many().Text()
             from closingQuote in QuotationMark
             select content).Token().Named("quoted string");

        public static readonly Parser<string> MultilineQuotedString =
            (from openingQuote in MultiQuotationMark
             from content in MultiQuotedStringElement.Many().Select(x => string.Join(String.Empty, x))
             from closingQuote in MultiQuotationMark
             select content).Token().Named("multiline quoted string");

        public static readonly Parser<UsingEntry> Using =
            (from usingKeyword in UsingKeyword
             from filePath in SingleLineQuotedString.Select(x => new StringWithPosition(x)).Positioned()
             from prefixedKeyword in PrefixedKeyword.Then(x => SingleLineQuotedString).Named("using prefix").Optional()
             select new UsingEntry(filePath, prefixedKeyword.GetOrDefault())).Token().Positioned().Named("using entry");

        public static readonly Parser<IEnumerable<UsingEntry>> Usings =
            (from firstUsing in Using
             from rest in Separator.Then(x => Using).Many()
             select new[] { firstUsing }.Concat(rest));

        public static readonly Parser<RangeValue> Range =
            (from opening in OpeningChevron
             from begin in HexadecimalUnsignedLong.Or(DecimalUnsignedLong)
             from comma in Comma
             from plus in PlusSign.Optional()
             from end in HexadecimalUnsignedLong.Or(DecimalUnsignedLong).Select(x => plus.IsEmpty ? x : begin + x).Where(x => begin <= x).Named("end of range that defines positive range")
             from closing in ClosingChevron
             select new RangeValue(begin, end)).Named("range");

        public static readonly Parser<EnumValue> EnumFull =
            (from firstElement in Identifier
             from rest in Parse.Char('.').Then(x => Identifier).XAtLeastOnce()
             select new EnumValue(new[] { firstElement }.Concat(rest))).Named("enum");

        public static readonly Parser<EnumValue> EnumShorthand =
            (from dot in Parse.Char('.')
             from id in Identifier
             select new EnumValue(id));

        public static readonly Parser<EnumValue> Enum = EnumFull.XOr(EnumShorthand);

        public static readonly Parser<ObjectValue> ObjectValue =
            (from newKeyword in NewKeyword
             from typeName in TypeName.Named("type name")
             from attributes in Parse.Ref(() => Attributes).XOptional()
             select new ObjectValue(typeName, attributes.GetOrElse(new Attribute[0]))).Named("inline object");

        public static readonly Parser<ReferenceValue> ReferenceValue = Identifier.Select(x => new ReferenceValue(x)).Named("reference");

        public static readonly Parser<BoolValue> BoolValue =
            TrueKeyword.Or(FalseKeyword).Select(x => new BoolValue(x)).Named("bool");

        public static readonly Parser<ListValue> EmptyList =
            (from opening in OpeningSquareBracket
             from closing in ClosingSquareBracket
             select new ListValue(Enumerable.Empty<Value>()));

        public static readonly Parser<ListValue> NonEmptyList =
            (from opening in OpeningSquareBracket
             from values in Value.DelimitedBy(Comma)
             from trailing in Comma.Optional()
             from closing in ClosingSquareBracket
             select new ListValue(values));

        public static readonly Parser<ListValue> ListValue = NonEmptyList.Or(EmptyList);

        public static readonly Parser<Value> Value = (SingleLineQuotedString.Or(MultilineQuotedString)).Select(x => new StringValue(x))
                                                                 .XOr<Value>(Range)
                                                                 .XOr(Number.Select(x => new NumericalValue(x)))
                                                                 .XOr(ObjectValue)
                                                                 .XOr(ListValue)
                                                                 .Or(Enum)
                                                                 .Or(BoolValue)
                                                                 .Or(ReferenceValue)
                                                                 .Positioned();

        public static readonly Parser<RegistrationInfo> RegistrationInfoInner =
            (from register in ReferenceValue.Named("register reference").Positioned()
             from registrationPoint in Value.XOptional().Named("registration point")
             select new RegistrationInfo(register, registrationPoint.GetOrDefault())).Named("registration info");

        public static readonly Parser<RegistrationInfo> RegistrationInfo = AtSign.Then(x => RegistrationInfoInner);

        public static readonly Parser<RegistrationInfo> NoneRegistrationInfo =
            (from atSign in AtSign
             from noneKeyword in NoneKeyword
             select new RegistrationInfo(null, null)).Named("none registration info");

        public static readonly Parser<IEnumerable<RegistrationInfo>> RegistrationInfos =
            (from atSign in AtSign
             from brace in OpeningBrace.Named("registration infos list")
             from first in RegistrationInfoInner
             from rest in Separator.Then(x => RegistrationInfoInner).XMany()
             from closingBrace in ClosingBrace.Named("registration infos list end")
             select new[] { first }.Concat(rest));

        public static readonly Parser<ConstructorOrPropertyAttribute> ConstructorOrPropertyAttribute =
            (from identifier in Identifier.Named("constructor or property name")
             from colon in Colon
             from value in Value.Named("constructor or property value").Or(NoneKeyword).Or(EmptyKeyword)
             select new ConstructorOrPropertyAttribute(identifier, value)).Named("constructor or property name and value");

        public static readonly Parser<string> QuotedMonitorStatementElement =
            (from openingQuote in QuotationMark
             from content in QuotedStringElement.Many().Text()
             from closingQuote in QuotationMark
             select openingQuote + content + closingQuote).Named("quoted monitor statement element");

        public static readonly Parser<string> MonitorStatementElement = Parse.AnyChar.Except(Separator.Or(OpeningBrace).Or(ClosingBrace).Or(QuotationMark)).XMany()
                                                                             .Or(QuotedMonitorStatementElement).Text().Named("monitor statement element");

        public static readonly Parser<string> MonitorStatement =
            (from elements in MonitorStatementElement.Many()
             select elements.Aggregate((x, y) => x + y)).Token().Named("monitor statement");

        public static readonly Parser<IEnumerable<string>> MonitorStatements =
            (from openingBrace in OpeningBrace.Named("init statement list")
             from firstLine in MonitorStatement
             from rest in Separator.Then(x => MonitorStatement).XMany()
             from closingBrace in ClosingBrace.Named("init statement list end")
             select new[] { firstLine }.Concat(rest));

        public static readonly Parser<InitAttribute> InitAttribute =
            (from initKeyword in InitKeyword
             from addSuffix in Identifier.Where(x => x == "add").Optional()
             from colon in Colon
             from initValue in MonitorStatements
             select new InitAttribute(initValue, !addSuffix.IsEmpty)).Named("init section");

        public static readonly Parser<ResetAttribute> ResetAttribute =
            (from resetKeyword in ResetKeyword
             from addSuffix in Identifier.Where(x => x == "add").Optional()
             from colon in Colon
             from resetValue in MonitorStatements
             select new ResetAttribute(resetValue, !addSuffix.IsEmpty)).Named("reset section");

        public static readonly Parser<IEnumerable<int>> IrqRange =
            (from leftSide in HexadecimalUnsignedInt.Or(DecimalUnsignedInt)
             from dash in Minus
             from rightSide in HexadecimalUnsignedInt.Or(DecimalUnsignedInt).Where(x => x != leftSide).Named(string.Format("number other than {0}", leftSide))
             select MakeSimpleRange(checked((int)leftSide), checked((int)rightSide)));

        public static Parser<IOption<T>> XOptional<T>(this Parser<T> parser)
        {
            if(parser == null) throw new ArgumentNullException(nameof(parser));

            return i =>
            {
                var pr = parser(i);

                if(pr.WasSuccessful)
                    return Result.Success(new Some<T>(pr.Value), pr.Remainder);

                if(!pr.Remainder.Equals(i))
                {
                    return Result.Failure<IOption<T>>(pr.Remainder, pr.Message, pr.Expectations);
                }

                return Result.Success(new None<T>(), i);
            };
        }

        public static Parser<string> MakeKeyword(string keyword)
        {
            Keywords.Add(keyword);
            return GeneralIdentifier.Where(x => x == keyword).Named(keyword + " keyword");
        }

        public static Parser<T> MakeKeyword<T>(string keyword, T obj)
        {
            Keywords.Add(keyword);
            return GeneralIdentifier.Where(x => x == keyword).Named(keyword + " keyword").Select(x => obj);
        }

        public static IEnumerable<int> MakeSimpleRange(int begin, int end)
        {
            if(end >= begin)
            {
                return Enumerable.Range(begin, end - begin + 1);
            }
            return Enumerable.Range(end, begin - end + 1).Reverse();
        }

        public static Parser<SingleOrMultiIrqEnd> GetIrqEnd(bool source)
        {
            var result = IrqRange.Select(x => new SingleOrMultiIrqEnd(x.Select(y => new IrqEnd(null, y))))
                                 .Or(HexadecimalInt.Or(DecimalInt).Select(x => new SingleOrMultiIrqEnd(new[] { new IrqEnd(null, x) })));
            if(source)
            {
                result = result.Or(Identifier.Select(x => new SingleOrMultiIrqEnd(new[] { new IrqEnd(x, 0) })));
            }
            return result.Positioned();
        }

        public static Parser<IEnumerable<SingleOrMultiIrqEnd>> GetIrqEnds(bool source)
        {
            return
                (from openingBracket in OpeningSquareBracket
                 from first in GetIrqEnd(source)
                 from rest in Comma.Then(x => GetIrqEnd(source)).XMany()
                 from closingBracket in ClosingSquareBracket
                 select new[] { first }.Concat(rest));
        }

        public static Parser<IrqReceiver> IrqReceiver =
            (from destinationName in ReferenceValue.Named("destination peripheral reference")
             from localIndex in Parse.Char('#').Then(x => Parse.Number.Select(y => (int?)int.Parse(y))).Named("local index").XOptional()
             select new IrqReceiver(destinationName, localIndex.GetOrDefault())).Positioned();

        public static readonly Parser<IrqDestinations> SimpleDestination =
           (from destinationIdentifier in IrqReceiver
            from at in AtSign
            from end in GetIrqEnd(false)
            select new IrqDestinations(destinationIdentifier, new SingleOrMultiIrqEnd[] { end }));

        public static readonly Parser<IrqDestinations> MultiDestination =
           (from destinationIdentifier in IrqReceiver
            from at in AtSign
            from ends in GetIrqEnds(false)
            select new IrqDestinations(destinationIdentifier, ends));

        public static readonly Parser<IrqAttribute> SimpleIrqAttribute =
            (from source in GetIrqEnd(true).Select(x => new[] { x }).Optional()
             from arrow in RightArrow
             from destination in SimpleDestination
             from rest in MultiplexSign.XOptional().Then(x => SimpleDestination).XMany()
             select new IrqAttribute(source.GetOrDefault(), new[] { destination }.Concat(rest)));

        public static readonly Parser<IrqAttribute> MultiIrqAttribute =
            (from sources in GetIrqEnds(true)
             from arrow in RightArrow
             from destination in MultiDestination
             from rest in MultiplexSign.XOptional().Then(x => MultiDestination).XMany()
             select new IrqAttribute(sources, new[] { destination }.Concat(rest)));

        public static readonly Parser<IrqAttribute> NoneIrqAttribute =
            (from source in GetIrqEnd(true).Select(x => new[] { x }).Optional()
             from arrow in RightArrow
             from noneKeyword in NoneKeyword
             select new IrqAttribute(source.GetOrDefault(), new[] { new IrqDestinations(null, null) }));

        public static readonly Parser<Attribute> Attribute = InitAttribute
            .Or<Attribute>(ResetAttribute)
            .Or<Attribute>(ConstructorOrPropertyAttribute)
            .Or(NoneIrqAttribute)
            .Or(SimpleIrqAttribute)
            .Or(MultiIrqAttribute)
            .Positioned().Named("attribute");

        public static readonly Parser<IEnumerable<Attribute>> AttributesInner =
            (from firstAttribute in Attribute
             from rest in Separator.Then(x => Attribute).XMany()
             select new[] { firstAttribute }.Concat(rest));

        public static readonly Parser<IEnumerable<Attribute>> Attributes =
            (from openingBrace in OpeningBrace.Named("attribute list")
             from attributes in AttributesInner.XOptional()
             from closingBrace in ClosingBrace.Named("attribute list end")
             select attributes.GetOrElse(new Attribute[0]));

        public static readonly Parser<Entry> Entry =
            (from localKeyword in LocalKeyword.Optional()
             from variableName in Identifier.Named("variable name")
             from colon in Colon
             from type in TypeName.XOptional().Named("type name")
             from registationInfo in RegistrationInfo.Or(NoneRegistrationInfo).Select(x => new[] { x }).Or(RegistrationInfos).XOptional()
             from alias in AsKeyword.Then(x => SingleLineQuotedString.Select(y => new StringWithPosition(y)).Named("alias").Positioned()).XOptional()
             from attributes in Attributes.XOptional()
             select new Entry(variableName, type.GetOrDefault(), registationInfo.GetOrDefault(), attributes.GetOrElse(new Attribute[0]), localKeyword.IsDefined, alias.GetOrDefault()))
                .Positioned().Token().Named("entry");

        public static readonly Parser<IEnumerable<Entry>> Entries =
            (from firstEntry in Entry
             from rest in Separator.Then(x => Entry).XMany()
             select new[] { firstEntry }.Concat(rest));

        public static readonly Parser<Description> Description =
            (from whitespace in Parse.WhiteSpace.Many() // we have to consume all whitespaces before deciding, because X decides on first char
             from usings in Usings.XOptional()
             from separator in Separator.Optional() // leftover separator from the last using before first entry; user cannot insert it, because it is not added by prelexer
             from entries in Entries.XOptional()
             select new Description(usings.GetOrElse(new UsingEntry[0]), entries.GetOrElse(new Entry[0]))).End();

        internal abstract class AbstractOption<T> : IOption<T>
        {
            public T GetOrDefault()
            {
                return IsEmpty ? default(T) : Get();
            }

            public abstract T Get();

            public bool IsDefined
            {
                get { return !IsEmpty; }
            }

            public abstract bool IsEmpty { get; }
        }

        internal sealed class Some<T> : AbstractOption<T>
        {
            public Some(T value)
            {
                _value = value;
            }

            public override T Get()
            {
                return _value;
            }

            public override bool IsEmpty
            {
                get { return false; }
            }

            private readonly T _value;
        }

        internal sealed class None<T> : AbstractOption<T>
        {
            public override T Get()
            {
                throw new InvalidOperationException("Cannot get value from None.");
            }

            public override bool IsEmpty
            {
                get { return true; }
            }
        }
    }
}