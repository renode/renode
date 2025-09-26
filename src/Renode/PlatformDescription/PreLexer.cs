//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Antmicro.Renode.PlatformDescription
{
    public static class PreLexer
    {
        public static IEnumerable<string> HandleMultilineStrings(IEnumerable<string> sourceLine, string path)
        {
            var multilineQuoteRegex = new Regex(MultilineStringDelimiter);
            var multilineString = new List<string>();
            var inMultilineString = false;
            var openingQuoteLine = new Tuple<int, string, int>(-1, "", -1);

            foreach(var currentLine in sourceLine.Select((value, index) => new { index, value }))
            {
                var line = currentLine.value;
                var validQuotes = CountUnescapedCharacters(line, multilineQuoteRegex, out List<int> validQuotesIndexes);
                var lastQuoteIndex = (validQuotesIndexes.Count != 0) ? validQuotesIndexes[validQuotesIndexes.Count - 1] : -1;

                if(inMultilineString)
                {
                    multilineString.Add(line);
                    if(validQuotes >= 1)
                    {
                        inMultilineString = false;
                        var str = string.Join("\n", multilineString);
                        multilineString.Clear();
                        yield return str;
                    }
                }
                else
                {
                    if(validQuotes == 0 || validQuotes == 2) // no quotes at all or opening and closing quote
                    {
                        yield return line;
                        continue;
                    }
                    else if(validQuotes != 1) // invalid multiple quotes in line
                    {
                        throw GetException(ParsingError.SyntaxError, currentLine.index, validQuotesIndexes[2], line,
                            "The start of one multiline string cannot be on the same line as the end of another", path);
                    }
                    openingQuoteLine = new Tuple<int, string, int>(currentLine.index, currentLine.value, lastQuoteIndex);
                    inMultilineString = true;
                    multilineString.Add(line);
                }
            }

            if(inMultilineString) //if closing quote was never found
            {
                var errorLine = openingQuoteLine.Item2;
                var errorQuoteIndex = openingQuoteLine.Item3;
                throw GetException(ParsingError.SyntaxError, openingQuoteLine.Item1, errorQuoteIndex, errorLine,
                                   "Unclosed multiline string", path);
            }
        }

        public static int CountUnescapedCharacters(string line, Regex regexCharacterToFind, out List<int> validQuotesIndexes, char escapeCharacter = '\\')
        {
            var matches = regexCharacterToFind.Matches(line);
            var validQuotesCount = 0;
            validQuotesIndexes = new List<int>();

            foreach(Match ma in matches)
            {
                var index = ma.Index - 1;
                var startIndex = index;
                var backslashCount = 0;

                while(index >= 0 && line[index] == escapeCharacter)
                {
                    backslashCount++;
                    index--;
                }

                if(backslashCount % 2 == 0)
                {
                    validQuotesCount++;
                    validQuotesIndexes.Add(startIndex);
                }
            }
            return validQuotesCount;
        }

        public static IEnumerable<string> Process(string source, string path = "")
        {
            // We remove '\r' so that we don't have to worry about line endings.
            var sourceInLines = source.Replace("\r", string.Empty).Split(new[] { '\n' }, StringSplitOptions.None);
            var lineSource = HandleMultilineStrings(sourceInLines, path);
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
                    FindResult found;
                    switch(found = FindInLine(line, ref currentIndex))
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
                    case FindResult.MultilineStringStart: // multiline strings are already rolled into one string containing \n here
                        var delimiter = found == FindResult.StringStart ? StringDelimiter : MultilineStringDelimiter;
                        currentIndex += delimiter.Length;
                        while(true)
                        {
                            var nextDelimiterIndex = line.IndexOf(delimiter, currentIndex);
                            if(nextDelimiterIndex == -1)
                            {
                                throw GetException(ParsingError.SyntaxError, lineNo, originalLine.Length - 1, originalLine, "Unterminated string.", path);
                            }
                            currentIndex = nextDelimiterIndex + delimiter.Length;
                            // if this is escaped quote, just ignore it
                            if(!IsEscapedPosition(line, nextDelimiterIndex))
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
                            if(line.Length - line.TrimStart().Length + 1 == currentIndex && // comment is the first meaningful thing in line
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
                case '\'':
                    if(line.Length >= currentIndex + MultilineStringDelimiter.Length && line.Substring(currentIndex, MultilineStringDelimiter.Length) == MultilineStringDelimiter)
                    {
                        currentIndex += MultilineStringDelimiter.Length;
                        return FindResult.MultilineStringStart;
                    }
                    break;
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
                if(line[i] == '"' && !IsEscapedPosition(line, i))
                {
                    inString = !inString;
                }
            }
        }

        private static bool IsEscapedPosition(string str, int position)
        {
            int numEscapes = 0;
            while(position - 1 - numEscapes >= 0 && str[position - 1 - numEscapes] == '\\')
            {
                numEscapes++;
            }
            // if there's an odd number of backslashes before this position, it is escaped
            return numEscapes % 2 == 1;
        }

        private const int SpacesPerIndent = 4;
        private const string StringDelimiter = "\"";
        private const string MultilineStringDelimiter = "'''";

        private enum FindResult
        {
            Nothing,
            StringStart,
            MultilineStringStart,
            MultilineCommentStart,
            SingleLineCommentStart
        }
    }
}