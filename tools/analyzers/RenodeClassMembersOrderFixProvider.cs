using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Composition;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CodeFixes;
using Microsoft.CodeAnalysis.CodeActions;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Editing;

namespace Antmicro.Renode.CustomAnalyzers
{
    [ExportCodeFixProvider(LanguageNames.CSharp, Name = nameof(RenodeClassMembersOrderFixProvider)), Shared]
    public class RenodeClassMembersOrderFixProvider : CodeFixProvider
    {
        public sealed override ImmutableArray<string> FixableDiagnosticIds =>
            ImmutableArray.Create(RenodeClassMembersOrderAnalyzer.DiagnosticId);

        public override FixAllProvider GetFixAllProvider() =>
            FixAllProvider.Create(async (context, document, _) =>
                await FixDocumentClassMembersOrder(document, context.CancellationToken).ConfigureAwait(false));

        public override Task RegisterCodeFixesAsync(CodeFixContext context)
        {
            var document = context.Document;
            // We have only one entry in FixableDiagnosticIds,
            // so there should be just one entry on the list.
            var diagnostic = context.Diagnostics.First();

            var codeAction = CodeAction.Create(
                title: "Fix Renode class member order",
                createChangedDocument: c => FixSingleClassMemberOrder(document, diagnostic, c),
                equivalenceKey: "RenodeClassMemberOrder"
            );

            context.RegisterCodeFix(codeAction, diagnostic);

            return Task.CompletedTask;
        }

        private async Task<Document> FixDocumentClassMembersOrder(
            Document document,
            CancellationToken cancellationToken
        )
        {
            var editor = await DocumentEditor.CreateAsync(document, cancellationToken);

            // This fix provider is capable of fixing members order also within nested calsses, on arbitrary level.
            // In order to do so, it must handle nested classes first. Since we list members recursively
            // in document prefix order, we just have to reverse list to start with nested classes.
            var classes = editor
                .OriginalRoot
                .DescendantNodes()
                .Where(node => node.IsKind(SyntaxKind.ClassDeclaration))
                .Reverse();

            foreach(var cls in classes)
            {
                var currentRoot = editor.GetChangedRoot();

                var declarations = cls
                    .ChildNodes()
                    .OfType<MemberDeclarationSyntax>();

                // We first find all misplaced members and remove them from tree.
                // When we reinsert removed nodes to tree, they are treated as new nodes, so we cannot reference them
                // in tree operations (i.e. we cannot use them as reference when inserting new nodes).
                // We also remember all well ordered nodes to use them as references when we reinsert misplaced nodes.
                var wellOrderedMembers = new List<MemberDeclarationSyntax>();
                var misplacedMembers = new List<MemberDeclarationSyntax>();

                var currentMember = RenodeClassMembersOrderAnalyzer.ClassMemberOrder.StaticConstructor;
                foreach(var declaration in declarations)
                {
                    if(RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(declaration, out var nextMember))
                    {
                        if(nextMember < currentMember)
                        {
                            misplacedMembers.Add(declaration);
                            editor.RemoveNode(declaration, SyntaxRemoveOptions.KeepNoTrivia);
                        }
                        else
                        {
                            wellOrderedMembers.Add(declaration);
                            currentMember = nextMember;
                        }
                    }
                }

                // This class already satisfies Renode class members order rule
                if(misplacedMembers.Count == 0)
                {
                    continue;
                }

                // We know that this class content will be modified, so we want to track this class
                // in case we need to move it later
                editor.TrackNode(cls);

                // At this point all members stored in wellOrderedMembers and misplacedMembers
                // have corresponding ClassMemberOrder, so we no longer need to check every call
                // to RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder.
                misplacedMembers.Sort((lhs, rhs) =>
                {
                    RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(lhs, out var lhsOrder);
                    RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(rhs, out var rhsOrder);
                    return lhsOrder.CompareTo(rhsOrder);
                });

                // If we are here, we know that there is at least one correct memeber and at least one misplaced member.
                // So calling MoveNext on Enumerator is safe.
                var correctMemberEnumerator = wellOrderedMembers.GetEnumerator();
                correctMemberEnumerator.MoveNext();

                var correctMember = correctMemberEnumerator.Current;
                RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(correctMember, out var correctOrder);

                // We keep last valid order to easily break loop
                RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(wellOrderedMembers.Last(), out var lastCorrectOrder);

                foreach(var misplacedMember in misplacedMembers)
                {
                    RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(misplacedMember, out var misplacedOrder);
                    if(misplacedOrder > lastCorrectOrder)
                    {
                        break;
                    }

                    while(misplacedOrder > correctOrder)
                    {
                        correctMemberEnumerator.MoveNext();
                        correctMember = correctMemberEnumerator.Current;
                        RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(correctMember, out correctOrder);
                    }

                    var upToDateMember = currentRoot.GetCurrentNode(misplacedMember) ?? misplacedMember;
                    editor.InsertBefore(correctMember, upToDateMember);
                }

                // correctMember now points to the last valid member.
                // We have to perform InsertAfter on remaining misplaced nodes
                // in reverse order to keep valid members order.
                misplacedMembers.Reverse();
                foreach(var misplacedMember in misplacedMembers)
                {
                    RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(misplacedMember, out var misplacedOrder);
                    if(misplacedOrder <= lastCorrectOrder)
                    {
                        break;
                    }
                    var upToDateMember = currentRoot.GetCurrentNode(misplacedMember) ?? misplacedMember;
                    editor.InsertAfter(correctMember, upToDateMember);
                }
            }

            return editor.GetChangedDocument();
        }

        private async Task<Document> FixSingleClassMemberOrder(
            Document document,
            Diagnostic diagnostic,
            CancellationToken cancellationToken
        )
        {
            var editor = await DocumentEditor.CreateAsync(document, cancellationToken);
            var root = editor.OriginalRoot;

            var misplacedDeclaration = root
                .FindToken(diagnostic.Location.SourceSpan.Start)
                .Parent
                .AncestorsAndSelf()
                .OfType<MemberDeclarationSyntax>()
                .First();

            if(!RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(misplacedDeclaration, out var misplacedOrder))
            {
                return document;
            }

            var classMembers = misplacedDeclaration
                .Parent
                .ChildNodes()
                .OfType<MemberDeclarationSyntax>();

            editor.RemoveNode(misplacedDeclaration, SyntaxRemoveOptions.KeepNoTrivia);

            var successor = classMembers
                .FirstOrDefault(
                    node => RenodeClassMembersOrderAnalyzer.TryGetClassMemberOrder(node, out var correctOrder) && misplacedOrder <= correctOrder);

            // If there isn't any member, that is greater or equal than misplaced declaration,
            // then it must be last declaration.
            if(successor == null)
            {
                editor.InsertAfter(classMembers.Last(), misplacedDeclaration);
            }
            else
            {
                editor.InsertBefore(successor, misplacedDeclaration);
            }

            return editor.GetChangedDocument();
        }
    }
}
