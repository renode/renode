//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Linq;
using System.Collections.Immutable;
using System.Text.RegularExpressions;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Diagnostics;

namespace Antmicro.Renode.CustomAnalyzers
{
    [DiagnosticAnalyzer(LanguageNames.CSharp)]
    public class RenodeCopyrightAnalyzer : DiagnosticAnalyzer
    {
        public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics =>
            ImmutableArray.Create(CopyrightDateRule, CopyrightFormatRule);

        public override void Initialize(AnalysisContext context)
        {
            context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
            context.EnableConcurrentExecution();
            context.RegisterSyntaxTreeAction(CheckCopyrights);
        }

        private void CheckCopyrights(SyntaxTreeAnalysisContext context)
        {
            var comments = context
                .Tree
                .GetRoot()
                .DescendantTrivia()
                .Where(node => node.IsKind(SyntaxKind.SingleLineCommentTrivia))
                .ToArray();

            var commentIdx = 0;
            for(var templateIdx = 0; templateIdx < CopyrightTemplate.Length; ++templateIdx)
            {
                // We don't have any more comments to check
                if(commentIdx >= comments.Length)
                {
                    context.ReportDiagnostic(Diagnostic.Create(CopyrightFormatRule, location: null));
                    return;
                }

                var comment = comments[commentIdx];
                var content = comment.ToString();
                var commentLine = comment
                    .GetLocation()
                    .GetLineSpan()
                    .StartLinePosition
                    .Line;

                // copyright line might be correct, but it's on wrong line
                if(commentLine != commentIdx)
                {
                    context.ReportDiagnostic(Diagnostic.Create(CopyrightFormatRule, location: null));
                }

                switch(templateIdx)
                {
                case AntmicroCopyrightLine:
                    CheckAntmicroCopyrights(context, comment);
                    break;
                case AdditionalCopyrightLine:
                    if(CheckAdditionalCopyrights(comment))
                    {
                        // We found additional copyright, but we adjust templateIdx
                        // because we don't know how many there will be.
                        templateIdx--;
                    }
                    else
                    {
                        // We end up pointing to the line after additional copyrights.
                        // Let's adjust pointer to not skip any line.
                        commentIdx--;
                    }
                    break;
                default:
                    if(content != CopyrightTemplate[templateIdx])
                    {
                        context.ReportDiagnostic(Diagnostic.Create(CopyrightFormatRule, comment.GetLocation()));
                    }
                    break;
                }
                commentIdx++;
            }
        }

        private void CheckAntmicroCopyrights(SyntaxTreeAnalysisContext context, SyntaxTrivia commentNode)
        {
            var content = commentNode.ToString();
            var regex = new Regex(CopyrightTemplate[AntmicroCopyrightLine]);
            var match = regex.Match(content);
            if(match.Success)
            {
                var copyrightYear = match.Groups[1].Value;
                var currentYear = DateTime.Today.Year.ToString();
                if(copyrightYear != currentYear)
                {
                    context.ReportDiagnostic(Diagnostic.Create(CopyrightDateRule, commentNode.GetLocation()));
                }
            }
            else
            {
                context.ReportDiagnostic(Diagnostic.Create(CopyrightFormatRule, commentNode.GetLocation()));
            }
        }

        private bool CheckAdditionalCopyrights(SyntaxTrivia commentNode)
        {
            var content = commentNode.ToString();
            var regex = new Regex(CopyrightTemplate[AdditionalCopyrightLine]);
            var match = regex.Match(content);
            return match.Success;
        }

        private static readonly DiagnosticDescriptor CopyrightDateRule = new DiagnosticDescriptor(
            "renode_copyright",
            "Copyright Date",
            "Copyright is not up to date",
            "License",
            DiagnosticSeverity.Warning,
            isEnabledByDefault: false,
            description: "Ensure that copyrights are up to date."
        );

        private static readonly DiagnosticDescriptor CopyrightFormatRule = new DiagnosticDescriptor(
            "renode_copyright",
            "Copyright Format",
            "Wrong copyright format",
            "License",
            DiagnosticSeverity.Warning,
            isEnabledByDefault: false,
            description: "Ensure that copyrights are in correct format."
        );

        private static readonly string[] CopyrightTemplate = {
            "//",
            @"// Copyright \(c\) 2010-(\d+) Antmicro",
            @"// Copyright \(c\) .*",
            "//",
            "// This file is licensed under the MIT License.",
            "// Full license text is available in 'licenses/MIT.txt'.",
            "//"
        };

        private const int AntmicroCopyrightLine = 1;
        private const int AdditionalCopyrightLine = 2;
    }
}
