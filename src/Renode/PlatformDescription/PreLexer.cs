//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Antmicro.Renode.PlatformDescription
{
    public static class PreLexer
    {
        public static IEnumerable<string> Process(string source, string path = "")
        {
            // We remove '\r' so that we don't have to worry about line endings.
            var lineSource = source.Replace("\r", string.Empty).Split(new[] { '\n' }, StringSplitOptions.None);
            var inputBraceLevel = 0;
            var outputBraceLevel = 0;

            var lineNo = -1;
            var enumerator = HandleComments(lineSource, path).GetEnumerator();
            var started = false; // will change to true if the file is not empty (or has only empty lines)
            while(enumerator.MoveNext())
            {
                lineNo++;
                if(!string.IsNullOrWhiteSpace(enumerator.Current))
                {
                    started = true;
                    break;
                }
                yield return enumerator.Current;
            }
            if(!started)
            {
                yield break;
            }

            var oldLine = enumerator.Current;
            var oldIndentLevel = GetIndentLevel(oldLine, lineNo, path);

            if(oldIndentLevel != 0)
            {
                throw GetException(ParsingError.WrongIndent, lineNo, 0, oldLine, "First line with text cannot be indented.", path);
            }

            if(!enumerator.MoveNext())
            {
                yield return oldLine;
                AccountBraceLevel(oldLine, ref outputBraceLevel);
                yield break;
            }

            var numberOfEmptyLines = 0;

            do
            {
                lineNo++;
                AccountBraceLevel(oldLine, ref inputBraceLevel);
                var newLine = enumerator.Current;

                // pass through all empty lines
                while(string.IsNullOrWhiteSpace(newLine))
                {
                    numberOfEmptyLines++;
                    if(!enumerator.MoveNext())
                    {
                        goto finish;
                    }
                    newLine = enumerator.Current;
                }

                if(inputBraceLevel > 0)
                {
                    AccountBraceLevel(oldLine, ref outputBraceLevel);
                    yield return oldLine;
                }
                else
                {
                    var newIndentLevel = GetIndentLevel(newLine, lineNo, path);
                    var result = DecorateLineIfNecessary(oldLine, oldIndentLevel, newIndentLevel, false);
                    yield return result;
                    AccountBraceLevel(result, ref outputBraceLevel);
                    oldIndentLevel = newIndentLevel;
                }

                for(var i = 0; i < numberOfEmptyLines; i++)
                {
                    yield return "";
                }
                numberOfEmptyLines = 0;

                oldLine = newLine;
            }
            while(enumerator.MoveNext());
finish:
            AccountBraceLevel(oldLine, ref inputBraceLevel);
            oldLine = DecorateLineIfNecessary(oldLine, oldIndentLevel, 0, true);
            yield return oldLine;
            AccountBraceLevel(oldLine, ref outputBraceLevel);
            if(inputBraceLevel == 0 && outputBraceLevel != 0)
            {
                // we only check output brace level if input was balanced, otherwise it does not make sense
                throw new ParsingException(ParsingError.InternalPrelexerError, "Internal prelexer error, unbalanced output with balanced input.");
            }

            for(var i = 0; i < numberOfEmptyLines; i++)
            {
                yield return "";
            }
        }

        private static IEnumerable<string> HandleComments(IEnumerable<string> lineSource, string path)
        {
            var inMultilineComment = false;
            var localBraceLevel = 0;
            var lineNo = -1;
            foreach(var originalLine in lineSource)
            {
                lineNo++;
                var line = originalLine;
                var currentIndex = 0;
                if(inMultilineComment)
                {
                    var closingIndex = line.IndexOf("*/", StringComparison.InvariantCulture);
                    if(closingIndex == -1)
                    {
                        yield return string.Empty; // no need to adjust brace level
                        continue;
                    }
                    if(localBraceLevel == 0 && closingIndex != line.TrimEnd().Length - 2)
                    {
                        throw GetException(ParsingError.SyntaxError, lineNo, closingIndex, originalLine, "Multiline comment in indent mode can only finish at the end of the line.", path);
                    }
                    var newLine = new StringBuilder(line);
                    for(var i = 0; i <= closingIndex + 1; i++)
                    {
                        newLine[i] = ' ';
                    }
                    line = newLine.ToString();
                    inMultilineComment = false;
                }
                while(true)
                {
                    switch(FindInLine(line, ref currentIndex))
                    {
                    case FindResult.Nothing:
                        AccountBraceLevel(line, ref localBraceLevel);
                        yield return line;
                        goto next;
                    case FindResult.SingleLineCommentStart:
                        line = line.Substring(0, currentIndex - 1);
                        AccountBraceLevel(line, ref localBraceLevel);
                        yield return line;
                        goto next;
                    case FindResult.StringStart:
                        currentIndex++;
                        while(true)
                        {
                            currentIndex = line.IndexOf('"', currentIndex) + 1;
                            if(currentIndex == 0) // means that IndexOf returned -1
                            {
                                throw GetException(ParsingError.SyntaxError, lineNo, originalLine.Length - 1, originalLine, "Unterminated string.", path);
                            }
                            // if this is escaped quote, just ignore it
                            if(line[currentIndex - 2] != '\\')
                            {
                                break;
                            }
                        }
                        break;
                    case FindResult.MultilineCommentStart:
                        var nextIndex = line.IndexOf("*/", currentIndex + 1, StringComparison.InvariantCulture) + 2;
                        if(nextIndex == 1) // means that IndexOf returned -1
                        {
                            inMultilineComment = true;
                            line = line.Substring(0, currentIndex - 1);
                            AccountBraceLevel(line, ref localBraceLevel);
                            yield return line;
                            goto next;
                        }
                        if(localBraceLevel == 0)
                        {
                            if(line.Length - line.TrimStart().Length  + 1 == currentIndex && // comment is the first meaningful thing in line
                               line.TrimEnd().Length != nextIndex) // but not the last one
                            {
                                throw GetException(ParsingError.SyntaxError, lineNo, currentIndex, originalLine,
                                                   "Single line multiline comment in indent mode cannot be the first non-whitespace element of a line if it is does not span to the end of the line.",
                                                   path);
                            }
                        }
                        var newLine = new StringBuilder(line);
                        for(var i = currentIndex - 1; i < nextIndex; i++)
                        {
                            newLine[i] = ' ';
                        }
                        line = newLine.ToString();
                        currentIndex = nextIndex;
                        break;
                    }
                }
            next:;
            }
        }

        private static FindResult FindInLine(string line, ref int currentIndex)
        {
            for(; currentIndex < line.Length; currentIndex++)
            {
                switch(line[currentIndex])
                {
                case '"':
                    return FindResult.StringStart;
                case '/':
                    if(line.Length > currentIndex + 1)
                    {
                        currentIndex++;
                        var nextChar = line[currentIndex];
                        if(nextChar == '*')
                        {
                            return FindResult.MultilineCommentStart;
                        }
                        else if(nextChar == '/')
                        {
                            if(currentIndex == 1 || (currentIndex >= 2 && line[currentIndex - 2] == ' '))
                            {
                                return FindResult.SingleLineCommentStart;
                            }
                        }
                    }
                    break;
                }
            }
            return FindResult.Nothing;
        }

        private static string DecorateLineIfNecessary(string line, int oldIndentLevel, int newIndentLevel, bool doNotInsertSemicolon)
        {
            var builder = new StringBuilder(line);
            if(newIndentLevel > oldIndentLevel)
            {
                return builder.Append('{', newIndentLevel - oldIndentLevel).ToString();
            }
            if((newIndentLevel < oldIndentLevel))
            {
                builder.Append('}', oldIndentLevel - newIndentLevel);
                if(!doNotInsertSemicolon)
                {
                    builder.Append(';');
                }
                return builder.ToString();
            }
            if(string.IsNullOrWhiteSpace(line))
            {
                return line;
            }
            return doNotInsertSemicolon ? line : line + ';';
        }

        private static ParsingException GetException(ParsingError error, int lineNo, int columnNo, string line, string message, string path)
        {
            message = string.Format("Error E{0:D2}: ", (int)error) + message + Environment.NewLine +
                                           string.Format("At {0}{1}:{2}:", path == "" ? "" : path + ':', lineNo + 1, columnNo + 1) + Environment.NewLine +
                                           line + Environment.NewLine + new string(' ', columnNo) + "^";
            throw new ParsingException(error, message);
                
        }

        private static int GetIndentLevel(string line, int lineNo, string path)
        {
            var spacesNo = line.TakeWhile(x => x == ' ').Count();
            if((spacesNo % SpacesPerIndent) != 0)
            {
                throw GetException(ParsingError.WrongIndent, lineNo, spacesNo - 1, line, 
                                   string.Format("Indent's length has to be multiple of {0}, this one is {1} spaces long.", SpacesPerIndent, spacesNo), path);
            }
            return spacesNo / SpacesPerIndent;
        }

        private static void AccountBraceLevel(string line, ref int braceLevel)
        {
            // we have to not take braces inside string into account; comments are already removed
            var inString = false;
            for(var i = 0; i < line.Length; i++)
            {
                var element = line[i];
                if(!inString)
                {
                    braceLevel += element == '{' ? 1 : element == '}' ? -1 : 0;
                }
                if(line[i] == '"' && (i == 0 || line[i - 1] != '\\'))
                {
                    inString = !inString;
                }
            }
        }

        private const int SpacesPerIndent = 4;

        private enum FindResult
        {
            Nothing,
            StringStart,
            MultilineCommentStart,
            SingleLineCommentStart
        }
    }
}
