//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using NUnit.Framework;
using Antmicro.Renode.PlatformDescription;

namespace Antmicro.Renode.UnitTests.AccessCondition
{
    [TestFixture]
    public class ParserTests
    {
        [TestCaseSource(nameof(AccessConditionParserTestCases))]
        public void ShouldParseAndConvertToDnf(string conditionString, string expectedDnfString)
        {
            var dnfExpression = AccessConditionParser.ParseCondition(conditionString);
            Assert.AreEqual(expectedDnfString, dnfExpression.ToString(), $"Input condition: '{conditionString}'");
        }

        private static IEnumerable<TestCaseData> AccessConditionParserTestCases()
        {
            // Trivial as the input is already a DNF term
            yield return new TestCaseData(
                "a",
                "(a)"
            );
            // Trivial as the input is already a DNF term
            yield return new TestCaseData(
                "!a",
                "(!a)"
            );
            // Trivial as the input is already a DNF term, but it has superfluous parentheses
            yield return new TestCaseData(
                "!((((((a))))))",
                "(!a)"
            );
            // Trivial as the input is already a DNF term, but it is a double negation
            yield return new TestCaseData(
                "!(((!(((a))))))",
                "(a)"
            );
            // Trivial as the input is already a DNF term
            yield return new TestCaseData(
                "!secure && initiator == cpu1",
                "(!secure && initiator == cpu1)"
            );
            // De Morgan's law yields a single DNF term
            yield return new TestCaseData(
                "!(privileged || secure)",
                "(!privileged && !secure)"
            );
            // De Morgan's law, output is a DNF formula of 2 terms
            yield return new TestCaseData(
                "!(privileged && secure)",
                "(!privileged) || (!secure)"
            );
            // Initiator conditions distributed over the state conditions
            yield return new TestCaseData(
                "secure && !privileged && (initiator == cpu1 || initiator == cpu2)",
                "(secure && !privileged && initiator == cpu1) || (secure && !privileged && initiator == cpu2)"
            );
            // An input condition which results in a fairly large DNF formula (4 terms, each with 3 conditions in it)
            yield return new TestCaseData(
                "(secure || busSecure) && (initiator == cpu1 || initiator == cpu2) && privileged",
                "(secure && initiator == cpu1 && privileged) || (secure && initiator == cpu2 && privileged) || (busSecure && initiator == cpu1 && privileged) || (busSecure && initiator == cpu2 && privileged)"
            );
        }
    }
}

