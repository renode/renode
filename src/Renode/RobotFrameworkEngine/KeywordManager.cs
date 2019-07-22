//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Antmicro.Renode.RobotFramework
{
    internal class KeywordManager : IDisposable
    {
        public KeywordManager()
        {
            keywords = new Dictionary<string, List<Keyword>>();
            objects = new Dictionary<Type, IRobotFrameworkKeywordProvider>();
        }

        public void Register(Type t)
        {
            if(!typeof(IRobotFrameworkKeywordProvider).IsAssignableFrom(t))
            {
                return;
            }

            foreach(var method in t.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var attr = method.GetCustomAttributes<RobotFrameworkKeywordAttribute>().SingleOrDefault();
                if(attr != null)
                {
                    var keyword = attr.Name ?? method.Name;
                    if(!keywords.ContainsKey(keyword))
                    {
                        keywords.Add(keyword, new List<Keyword>());
                    }

                    keywords[keyword].Add(new Keyword(this, method));
                }
            }
        }

        public object GetOrCreateObject(Type declaringType)
        {
            IRobotFrameworkKeywordProvider result;
            if(!objects.TryGetValue(declaringType, out result))
            {
                result = (IRobotFrameworkKeywordProvider)Activator.CreateInstance(declaringType);
                objects.Add(declaringType, result);
            }

            return result;
        }

        public KeywordLookupResult TryExecuteKeyword(string keywordName, string[] arguments, out object keywordResult)
        {
            keywordResult = null;
            if(!keywords.TryGetValue(keywordName, out var candidates))
            {
                return KeywordLookupResult.KeywordNotFound;
            }
            object[] parsedArguments = null;
            var keyword = candidates.FirstOrDefault(x => x.TryMatchArguments(arguments, out parsedArguments));
            if(keyword == null)
            {
                return KeywordLookupResult.ArgumentsNotMatched;
            }
            if(!keyword.ShouldNotBeReplayed)
            {
                Recorder.Instance.RecordEvent(keywordName, arguments);
            }
            keywordResult = keyword.Execute(parsedArguments);
            return KeywordLookupResult.Success;
        }

        public string[] GetRegisteredKeywords()
        {
            return keywords.Keys.ToArray();
        }

        public void Dispose()
        {
            foreach(var obj in objects)
            {
                obj.Value.Dispose();
            }
        }
        private readonly Dictionary<string, List<Keyword>> keywords;
        private readonly Dictionary<Type, IRobotFrameworkKeywordProvider> objects;

        public enum KeywordLookupResult
        {
            Success,
            KeywordNotFound,
            ArgumentsNotMatched
        }
    }
}

