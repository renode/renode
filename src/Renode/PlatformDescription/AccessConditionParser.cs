//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
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

            foreach(var term in formula.Terms)
            {
                var conditions = term.Conditions;
                // There can only be one initiator condition per term
                var initiator = conditions.OfType<InitiatorConditionNode>().SingleOrDefault()?.Initiator;
                var initiatorKey = initiator ?? "";
                conditions = conditions.Where(c => !(c is InitiatorConditionNode)).ToList();

                if(!result.ContainsKey(initiatorKey))
                {
                    result[initiatorKey] = new List<StateMask>();
                }
                var stateBitsForInitiator = getStateBits(initiator);
                if(conditions.Any() && !(stateBitsForInitiator?.Any() ?? false))
                {
                    throw new RecoverableException($"Encountered a condition for initiator '{initiatorKey}' but it has no state bits");
                }
                result[initiatorKey].Add(EvaluateOne(conditions, stateBitsForInitiator, initiatorKey));
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

        /// <remark>
        /// Mind that stateBits might be null if the initiator does not implement <see cref="Peripherals.IPeripheralWithTransactionState">
        /// </remark>
        private static StateMask EvaluateOne(IReadOnlyList<ConditionNode> conditions, IReadOnlyDictionary<string, int> stateBits, string initiatorName)
        {
            var result = new StateMask();
            foreach(var condition in conditions)
            {
                if(!stateBits.TryGetValue(condition.Condition, out var bitPosition))
                {
                    throw new RecoverableException($"Unknown state bit '{condition.Condition}' for initiator '{initiatorName}'");
                }
                if(result.HasMaskBit(bitPosition))
                {
                    throw new RecoverableException($"Condition conflict for {condition} for initiator '{initiatorName}'");
                }
                result = result.WithBitValue(bitPosition, !condition.Negated);
            }
            return result;
        }
    }
}
