//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Linq;

using Antmicro.Renode.PlatformDescription.Syntax;

using NUnit.Framework;

using Sprache;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class ParserPrimitivesTest
    {
        [Test]
        public void ShouldParseHexadecimalLong([Values("0x1000", "0x12AB", "0x0ff")] string number)
        {
            var input = new Input(number);
            var result = Grammar.HexadecimalUnsignedLong(input);
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(long.Parse(number.Substring(2), System.Globalization.NumberStyles.HexNumber), result.Value);
        }

        [Test]
        public void ShouldParseDecimalRange()
        {
            var source = "<100, 200>";
            var result = Grammar.Range(new Input(source));
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(new Range(100, 100), result.Value.ToRange());
        }

        [Test]
        public void ShouldParseHexadecimalRange()
        {
            var source = "<0x0, 0x1000>";
            var result = Grammar.Range(new Input(source));
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(new Range(0, 0x1000), result.Value.ToRange());
        }

        [Test]
        public void ShouldParseMixedRangeWithPlus()
        {
            var source = "<100, +0x100>";
            var result = Grammar.Range(new Input(source));
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(new Range(100, 0x100), result.Value.ToRange());
        }

        [Test]
        public void ShouldParseHexadecimalRangeWithPlus()
        {
            var source = "<0x1000, +0x1000>";
            var result = Grammar.Range(new Input(source));
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(new Range(0x1000, 0x1000), result.Value.ToRange());
        }

        [Test]
        public void ShouldNotParseNegativeRange()
        {
            var source = "<0x1000, 0x100>";
            var result = Grammar.Range(new Input(source));
            Assert.IsFalse(result.WasSuccessful);
        }

        [Test]
        public void ShouldParseNumber(
            [Values("0x1234", "-0x123", "- 0x36", "22", "-13", "-  45", "1.0", "-3.45")]
            string number)
        {
            var source = new Input(number);
            var result = Grammar.Number.End()(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);
            Assert.AreEqual(number.Replace(" ", string.Empty), result.Value);
        }

        [Test]
        public void ShouldNotParseNumber(
            [Values("0xghi", "12 .34", ".45", "345-")]
            string number)
        {
            var source = new Input(number);
            var result = Grammar.Number.End()(source);
            Assert.IsFalse(result.WasSuccessful);
        }

        [Test]
        public void ShouldParsePositiveIrqRange()
        {
            var source = new Input("3 - 5");
            var result = Grammar.IrqRange.End()(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);

            CollectionAssert.AreEquivalent(new[] { 3, 4, 5 }, result.Value);
        }

        [Test]
        public void ShouldParseNegativeIrqRange()
        {
            var source = new Input("7 - 4");
            var result = Grammar.IrqRange.End()(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);

            CollectionAssert.AreEquivalent(new[] { 7, 6, 5, 4 }, result.Value);
        }

        [Test]
        public void ShouldParseIrqSources()
        {
            var source = new Input("[1,2, 4-6, IRQ]");
            var result = Grammar.GetIrqEnds(true).End()(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);

            var flattenedIrqSources = result.Value.SelectMany(x => x.Ends).ToArray();
            Assert.AreEqual(1, flattenedIrqSources[0].Number);
            Assert.AreEqual(2, flattenedIrqSources[1].Number);
            Assert.AreEqual(4, flattenedIrqSources[2].Number);
            Assert.AreEqual(5, flattenedIrqSources[3].Number);
            Assert.AreEqual(6, flattenedIrqSources[4].Number);
            Assert.AreEqual("IRQ", flattenedIrqSources[5].PropertyName);
        }

        [Test]
        public void ShouldParseQuotedString()
        {
            var source = new Input("\"some text\"");
            var result = Grammar.SingleLineQuotedString(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);

            Assert.AreEqual("some text", result.Value);
        }

        [Test]
        public void ShouldParseQuotedStringWithASemicolon()
        {
            var source = new Input ("\"some;text\"");
            var result = Grammar.SingleLineQuotedString(source);
            Assert.IsTrue(result.WasSuccessful, result.Message);

            Assert.AreEqual("some;text", result.Value);
        }
    }
}