//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;

using Antmicro.Renode.PlatformDescription;

using NUnit.Framework;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    [TestFixture]
    public class PreLexerTests
    {
        [Test]
        public void ShouldProcessEmptyFile()
        {
            var result = PreLexer.Process(string.Empty);
            CollectionAssert.AreEquivalent(string.Empty, result.First());
        }

        [Test]
        public void ShouldProcessSimpleFile()
        {
            var source = @"first line
second line
    first indented
    second indented
third line";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"first line;
second line{
    first indented;
    second indented};
third line");

            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldProcessDoubleDedent()
        {
            var source = @"first line
second line
    first indented
    second indented

third line";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"first line;
second line{
    first indented;
    second indented};

third line");

            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldProcessDoubleDedentAtTheEndOfFile()
        {
            var source = @"first line
second line
    first indented";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"first line;
second line{
    first indented}");

            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldProcessTwoLinesWithNoIndent()
        {
            var source = @"
line1
line2";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1;
line2");
            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldProcessTwoLinesWithNoIndentAndSeparation()
        {
            var source = @"
line1

line2";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1;

line2");
            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldHandleEmptyLinesAtTheEndOfSource()
        {
            var source = @"
line1
line2

";
            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1;
line2

");
            CollectionAssert.AreEquivalent(expectedResult, result);
        }

        [Test]
        public void ShouldNotProcessIndentInBraces()
        {
            var source = @"
line1 { 
    line2 }";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 { 
    line2 }");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleCorrectLineComments()
        {
            var source = @"
line1 { // something
    line2 }";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 { 
    line2 }");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleUncorrectLineComments()
        {
            var source = @"
line1 {// something
    line2 }";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 {// something
    line2 }");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleBeginningLineComment()
        {
            var source = @"
// something
line1 {
    line2 }";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"

line1 {
    line2 }");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleLineCommentsAndStrings()
        {
            var source = @"
line1 ""something with //"" ""another // pseudo comment"" { // and here goes real comment
    line2 }";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 ""something with //"" ""another // pseudo comment"" { 
    line2 }");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldFailOnUnterminatedString()
        {
            var source = @"
line1 ""i'm unterminated";

            var result = PreLexer.Process(source);
            var exception = Assert.Throws<ParsingException>(() => result.ToArray());
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldHandleMultilineCommentsInOneLine()
        {
            var source = @"
line1 used as a ruler1234            123456789                1234
line 2/* first comment*/ ""string with /*"" /* second comment */ something";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 used as a ruler1234            123456789                1234;
line 2                   ""string with /*""                      something");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleMultilineComments()
        {
            var source = @"
line1/* here we begin
    here it goes
more
more
    here we finish*/
line2";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1;




line2");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleMultilineCommentsWithinBraces()
        {
            var source = @"
line1 { /* here we begin
    here it goes
here the comment ends*/ x: 5 }
line2";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 { 

                        x: 5 };
line2");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldFailIfTheMultilineCommentFinishesBeforeEndOfLine()
        {
            var source = @"
line1 /* here we begin
    here it goes
here the comment ends*/ x: 5
line2";

            var result = PreLexer.Process(source);
            var exception = Assert.Throws<ParsingException>(() => result.ToArray());
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        [Test]
        public void ShouldProcessBraceInString()
        {
            var source = @"
line1 ""{ \"" {""
line2";

            var result = PreLexer.Process(source);

            var expectedResult = SplitUsingNewline(@"
line1 ""{ \"" {"";
line2");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleTextOnTheFirstLine()
        {
            var source = @"onlyLine";

            var result = PreLexer.Process(source).ToArray();

            var expectedResult = SplitUsingNewline(@"onlyLine");

            CollectionAssert.AreEqual(expectedResult, result);
        }

        [Test]
        public void ShouldHandleInitialIndent()
        {
            var source = @"
    first line
    second line
        first indented
        second indented
    third line";
            var result = PreLexer.Process(source);

            var exception = Assert.Throws<ParsingException>(() => result.ToArray());
            Assert.AreEqual(ParsingError.WrongIndent, exception.Error);
        }

        [Test]
        public void ShouldFailOnSingleLineMultilineComment()
        {
            var source = @"
first line
    /*something*/ second line";

            var result = PreLexer.Process(source);

            var exception = Assert.Throws<ParsingException>(() => result.ToArray());
            Assert.AreEqual(ParsingError.SyntaxError, exception.Error);
        }

        private static string[] SplitUsingNewline(string source)
        {
            return source.Replace("\r", string.Empty).Split(new[] { '\n' }, StringSplitOptions.None);
        }
    }
}