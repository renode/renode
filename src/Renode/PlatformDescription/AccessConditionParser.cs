//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Sprache;

namespace Antmicro.Renode.PlatformDescription
{
    public class AccessConditionParser
    {
        public static DnfFormula ParseCondition(string condition)
        {
            return DnfFormula.FromDnfTree(ParseExpression(condition).ToDnf());
        }

        public static Dictionary<string, List<StateMask>> EvaluateWithStateBits(DnfFormula formula, Func<string, IReadOnlyDictionary<string, int>> getStateBits)
        {
            var result = new Dictionary<string, List<StateMask>>();

            // A term can have multiple conditions but up to one initiator.
            foreach(var term in formula.Terms)
            {
                var initiator = term.Conditions.OfType<InitiatorConditionNode>().SingleOrDefault()?.Initiator;

                // Empty string is used as a key if an initiator wasn't specified.
                var initiatorKey = initiator ?? string.Empty;
                if(!result.ContainsKey(initiatorKey))
                {
                    result[initiatorKey] = new List<StateMask>();
                }

                // If `initiator` is null then `stateBits` will contain common state bits for all IPeripheralWithTransactionState.
                //
                // It can be null if:
                // 1. `initiator` does not implement IPeripheralWithTransactionState,
                // 2. `initiator` is null and there's no peripheral implementing IPeripheralWithTransactionState.
                var stateBits = getStateBits(initiator);

                var conditions = term.Conditions.Where(c => !(c is InitiatorConditionNode));
                if(conditions.Any())
                {
                    if(stateBits == null || !stateBits.Any())
                    {
                        var message = new StringBuilder("Conditions provided (")
                            .Append(string.Join(" && ", conditions))
                            .Append(") but ")
                            .Append(initiator == null
                                    ? $"there are no peripherals implementing {nameof(Peripherals.IPeripheralWithTransactionState)} or they have no common state bits"
                                    : $"the initiator '{initiator}' doesn't implement {nameof(Peripherals.IPeripheralWithTransactionState)} or has no state bits"
                            ).ToString();
                        throw new RecoverableException(message);
                    }
                }

                var termStateMask = new StateMask();
                foreach(var condition in conditions)
                {
                    var initiatorString = initiator == null
                        ? $"peripherals implementing {nameof(Peripherals.IPeripheralWithTransactionState)} (initiator not specified)"
                        : $"the initiator '{initiator}'";

                    if(!stateBits.TryGetValue(condition.Condition, out var bitPosition))
                    {
                        var supportedBitsString = "'" + string.Join("', '", stateBits.Select(pair => pair.Key)) + "'";
                        throw new RecoverableException($"Provided condition is unsupported by {initiatorString}: {condition.Condition}; supported conditions: {supportedBitsString}");
                    }

                    if(termStateMask.HasMaskBit(bitPosition))
                    {
                        throw new RecoverableException($"Conditions conflict detected for {initiatorString}: {condition.Condition}");
                    }

                    // The given StateMask bit should be unset if the condition is negated, otherwise set.
                    var bitShouldBeSet = !condition.Negated;
                    termStateMask = termStateMask.WithBitValue(bitPosition, bitShouldBeSet);
                }
                result[initiatorKey].Add(termStateMask);
            }
            return result;
        }

        private static AstNode ParseExpression(string expr)
        {
            return OrTerm.Parse(expr);
        }

        private static Parser<IEnumerable<char>> OrOp => Parse.String("||").Token();

        private static Parser<AstNode> OrTerm =>
            Parse.ChainOperator(OrOp, AndTerm, (op, l, r) => new OrNode(l, r));

        private static Parser<IEnumerable<char>> AndOp => Parse.String("&&").Token();

        private static Parser<AstNode> AndTerm =>
            Parse.ChainOperator(AndOp, NegateTerm, (op, l, r) => new AndNode(l, r));

        private static Parser<AstNode> NegateTerm =>
            NegatedFactor
            .Or(Factor);

        private static Parser<AstNode> NegatedFactor =>
            from _ in Parse.Char('!').Token()
            from expr in Factor
            select new NotNode(expr);

        private static Parser<AstNode> Factor =>
            SubExpression
            .Or(InitiatorCondition)
            .Or(Condition);

        private static Parser<AstNode> SubExpression =>
            from lparen in Parse.Char('(').Token()
            from expr in OrTerm
            from rparen in Parse.Char(')').Token()
            select expr;

        private static Parser<string> GenericToken => Parse.Regex(@"\w+").Token();

        private static Parser<AstNode> Condition =>
            GenericToken
            .Select(name => new ConditionNode(name));

        private static Parser<IEnumerable<char>> InitiatorKeyword => Parse.String("initiator").Token();

        private static Parser<IEnumerable<char>> EqualsOp => Parse.String("==").Token();

        private static Parser<AstNode> InitiatorCondition =>
            from _ in InitiatorKeyword
            from __ in EqualsOp
            from initiator in GenericToken
            select new InitiatorConditionNode(initiator);

        public abstract class AstNode
        {
            public abstract AstNode ToDnf();
        }

        public class AndNode : AstNode
        {
            public AndNode(AstNode left, AstNode right)
            {
                Left = left;
                Right = right;
            }

            public override AstNode ToDnf()
            {
                var leftDnf = Left.ToDnf();
                var rightDnf = Right.ToDnf();
                if(leftDnf is OrNode leftOr)
                {
                    // (l.l || l.r) && r to (l.l && r) || (l.r && r)
                    // Recursively call ToDnf on it to handle cases like `(a || b) && (c || d)`
                    return new OrNode(new AndNode(leftOr.Left, rightDnf), new AndNode(leftOr.Right, rightDnf)).ToDnf();
                }
                if(rightDnf is OrNode rightOr)
                {
                    // l && (r.l || r.r) to (l && r.l) || (l && r.r)
                    return new OrNode(new AndNode(leftDnf, rightOr.Left), new AndNode(leftDnf, rightOr.Right)).ToDnf();
                }
                return new AndNode(leftDnf, rightDnf);
            }

            public override string ToString() => $"({Left} && {Right})";

            public readonly AstNode Left;
            public readonly AstNode Right;
        }

        public class OrNode : AstNode
        {
            public OrNode(AstNode left, AstNode right)
            {
                Left = left;
                Right = right;
            }

            public override AstNode ToDnf()
            {
                return new OrNode(Left.ToDnf(), Right.ToDnf());
            }

            public override string ToString() => $"({Left} || {Right})";

            public readonly AstNode Left;
            public readonly AstNode Right;
        }

        public class NotNode : AstNode
        {
            public NotNode(AstNode operand)
            {
                Operand = operand;
            }

            public override AstNode ToDnf()
            {
                if(Operand is AndNode and)
                {
                    // !(l && r) to (!l) || (!r)
                    return new OrNode(new NotNode(and.Left).ToDnf(), new NotNode(and.Right).ToDnf());
                }
                if(Operand is OrNode or)
                {
                    // !(p || q) to (!p) && (!q)
                    return new AndNode(new NotNode(or.Left).ToDnf(), new NotNode(or.Right).ToDnf());
                }
                if(Operand is NotNode not)
                {
                    return not.Operand.ToDnf();
                }
                return this;
            }

            public override string ToString() => $"!{Operand}";

            public readonly AstNode Operand;
        }

        public class ConditionNode : AstNode
        {
            public ConditionNode(string condition, bool negated = false)
            {
                Condition = condition;
                Negated = negated;
            }

            public override AstNode ToDnf() => this;

            public override string ToString() => $"{(Negated ? "!" : "")}{Condition}";
            public ConditionNode Negation => new ConditionNode(Condition, !Negated);

            public readonly string Condition;
            public readonly bool Negated;
        }

        public class InitiatorConditionNode : ConditionNode
        {
            public InitiatorConditionNode(string initiator) : base($"initiator == {initiator}")
            {
                Initiator = initiator;
            }

            public readonly string Initiator;
        }

        public class DnfTerm
        {
            public DnfTerm(IReadOnlyList<ConditionNode> conditions)
            {
                Conditions = conditions;
            }

            public override string ToString() => $"({string.Join(" && ", Conditions)})";

            public readonly IReadOnlyList<ConditionNode> Conditions;
        }

        public class DnfFormula
        {
            public DnfFormula(IReadOnlyList<DnfTerm> terms)
            {
                Terms = terms;
            }

            public static DnfFormula FromDnfTree(AstNode root)
            {
                var terms = new List<DnfTerm>();
                GatherDnfTerms(root, terms);
                return new DnfFormula(terms);
            }

            private static void GatherDnfTerms(AstNode node, List<DnfTerm> terms)
            {
                if(node is OrNode orNode)
                {
                    GatherDnfTerms(orNode.Left, terms);
                    GatherDnfTerms(orNode.Right, terms);
                }
                else if(node is AndNode || node is ConditionNode || node is NotNode)
                {
                    var conditions = new List<ConditionNode>();
                    GatherConditions(node, conditions);
                    terms.Add(new DnfTerm(conditions));
                }
                else
                {
                    throw new InvalidOperationException($"Unexpected node type: {node.GetType().FullName}");
                }
            }

            private static void GatherConditions(AstNode node, List<ConditionNode> conditions)
            {
                if(node is ConditionNode conditionNode)
                {
                    conditions.Add(conditionNode);
                }
                else if(node is NotNode notNode)
                {
                    conditions.Add(((ConditionNode)notNode.Operand).Negation);
                }
                else if(node is AndNode andNode)
                {
                    GatherConditions(andNode.Left, conditions);
                    GatherConditions(andNode.Right, conditions);
                }
                else
                {
                    throw new InvalidOperationException($"Unexpected node type: {node.GetType().FullName}");
                }
            }

            public override string ToString() => $"{string.Join(" || ", Terms)}";

            public readonly IReadOnlyList<DnfTerm> Terms;
        }
    }
}
