//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;

namespace Antmicro.Renode.CustomAnalyzers
{
    [DiagnosticAnalyzer(LanguageNames.CSharp)]
    public class RenodeClassMembersOrderAnalyzer : DiagnosticAnalyzer
    {
        public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics =>
            ImmutableArray.Create(ClassMembersOrderRule);

        public override void Initialize(AnalysisContext context)
        {
            context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
            context.EnableConcurrentExecution();
            context.RegisterSyntaxTreeAction(CheckClassMembersOrder);
        }

        private void CheckClassMembersOrder(SyntaxTreeAnalysisContext context)
        {
            var classes = context
                .Tree
                .GetRoot()
                .DescendantNodes()
                .Where(node => node.IsKind(SyntaxKind.ClassDeclaration));

            foreach(var cls in classes)
            {
                var declarations = cls
                    .ChildNodes()
                    .OfType<MemberDeclarationSyntax>();

                var currentMember = ClassMemberOrder.StaticConstructor;

                foreach(var declaration in declarations)
                {
                    if(TryGetClassMemberOrder(declaration, out var nextMember))
                    {
                        if(nextMember < currentMember)
                        {
                            var diagnostic = Diagnostic.Create(
                                ClassMembersOrderRule,
                                declaration.GetLocation(),
                                new object[] {currentMember, nextMember}
                            );
                            context.ReportDiagnostic(diagnostic);
                        }
                        currentMember = nextMember;
                    }
                }
            }
        }

        private static bool TryGetClassMemberOrder(MemberDeclarationSyntax node, out ClassMemberOrder classMemberOrder)
        {
            var modifiers = node
                .Modifiers
                .Aggregate("", (acc, val) => $"{acc}_{val}");
            var id = $"{modifiers}_{node.Kind()}";

            if(ClassMembersOrderMap.TryGetValue(id, out classMemberOrder))
            {
                return true;
            }
            return false;
        }

        private static readonly DiagnosticDescriptor ClassMembersOrderRule = new DiagnosticDescriptor(
            "renode_class_members_order",
            "Class Members Order",
            "Wrong Class Members Order: {1} should be placed before {0}",
            "Design",
            DiagnosticSeverity.Warning,
            isEnabledByDefault: false,
            description: "Checks if class members order is preserved."
        );


#pragma warning disable SA1509
        // SA1509 - No space before opening braces
        private static readonly Dictionary<string, ClassMemberOrder> ClassMembersOrderMap = new Dictionary<string, ClassMemberOrder>
        {
            {"_static_ConstructorDeclaration",                      ClassMemberOrder.StaticConstructor},
            {"_public_static_MethodDeclaration",                    ClassMemberOrder.PublicStaticMethod},
            {"_public_static_PropertyDeclaration",                  ClassMemberOrder.PublicStaticProperty},
            {"_public_static_explicit_OperatorDeclaration",         ClassMemberOrder.PublicStaticExplicitOperator},
            {"_public_static_implicit_OperatorDeclaration",         ClassMemberOrder.PublicStaticImplicitOperator},
            {"_public_static_FieldDeclaration",                     ClassMemberOrder.PublicStaticField},
            {"_public_ConstructorDeclaration",                      ClassMemberOrder.PublicConstructor},
            {"_public_MethodDeclaration",                           ClassMemberOrder.PublicMethod},
            {"_public_abstract_MethodDeclaration",                  ClassMemberOrder.PublicAbstractMethod},
            {"_public_PropertyDeclaration",                         ClassMemberOrder.PublicProperty},
            {"_public_EventDeclaration",                            ClassMemberOrder.PublicEvent},
            {"_public_readonly_FieldDeclaration",                   ClassMemberOrder.PublicReadonlyField},
            {"_public_ConstDeclaration",                            ClassMemberOrder.PublicConst},

            {"_protected_static_MethodDeclaration",                 ClassMemberOrder.ProtectedStaticMethod},
            {"_protected_static_PropertyDeclaration",               ClassMemberOrder.ProtectedStaticProperty},
            {"_protected_static_explicit_OperatorDeclaration",      ClassMemberOrder.ProtectedStaticExplicitOperator},
            {"_protected_static_implicit_OperatorDeclaration",      ClassMemberOrder.ProtectedStaticImplicitOperator},
            {"_protected_static_FieldDeclaration",                  ClassMemberOrder.ProtectedStaticField},
            {"_protected_ConstructorDeclaration",                   ClassMemberOrder.ProtectedConstructor},
            {"_protected_MethodDeclaration",                        ClassMemberOrder.ProtectedMethod},
            {"_protected_PropertyDeclaration",                      ClassMemberOrder.ProtectedProperty},
            {"_protected_EventDeclaration",                         ClassMemberOrder.ProtectedEvent},
            {"_protected_ConstDeclaration",                         ClassMemberOrder.ProtectedConst},

            {"_private_static_MethodDeclaration",                   ClassMemberOrder.PrivateStaticMethod},
            {"_private_static_FieldDeclaration",                    ClassMemberOrder.PrivateStaticField},
            {"_private_ConstructorDeclaration",                     ClassMemberOrder.PrivateConstructor},
            {"_private_MethodDeclaration",                          ClassMemberOrder.PrivateMethod},
            {"_private_PropertyDeclaration",                        ClassMemberOrder.PrivateProperty},
            {"_private_FieldDeclaration",                           ClassMemberOrder.PrivateField},
            {"_private_ConstDeclaration",                           ClassMemberOrder.PrivateConst},

            {"_public_ClassDeclaration",                            ClassMemberOrder.PublicClass},
            {"_public_DelegateDeclaration",                         ClassMemberOrder.PublicDelegate},
            {"_public_EnumDeclaration",                             ClassMemberOrder.PublicEnum},

            {"_protected_ClassDeclaration",                         ClassMemberOrder.ProtectedClass},
            {"_protected_DelegateDeclaration",                      ClassMemberOrder.ProtectedDelegate},
            {"_protected_EnumDeclaration",                          ClassMemberOrder.ProtectedEnum},

            {"_private_ClassDeclaration",                           ClassMemberOrder.PrivateClass},
            {"_private_DelegateDeclaration",                        ClassMemberOrder.PrivateDelegate},
            {"_private_EnumDeclaration",                            ClassMemberOrder.PrivateEnum},
        };
#pragma warning restore SA1509

        // Order of fileds in this Enum is important.
        // It specifies allowed order of class members.
        private enum ClassMemberOrder
        {
            StaticConstructor,
            PublicStaticMethod,
            PublicStaticProperty,
            PublicStaticExplicitOperator,
            PublicStaticImplicitOperator,
            PublicStaticField,
            PublicConstructor,
            PublicMethod,
            PublicAbstractMethod,
            PublicProperty,
            PublicEvent,
            PublicReadonlyField,
            PublicConst,
            ProtectedStaticMethod,
            ProtectedStaticProperty,
            ProtectedStaticExplicitOperator,
            ProtectedStaticImplicitOperator,
            ProtectedStaticField,
            ProtectedConstructor,
            ProtectedMethod,
            ProtectedProperty,
            ProtectedEvent,
            ProtectedConst,
            PrivateStaticMethod,
            PrivateStaticField,
            PrivateConstructor,
            PrivateMethod,
            PrivateProperty,
            PrivateField,
            PrivateConst,
            PublicClass,
            PublicDelegate,
            PublicEnum,
            ProtectedClass,
            ProtectedDelegate,
            ProtectedEnum,
            PrivateClass,
            PrivateDelegate,
            PrivateEnum,
        }
    }
}
