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

        public bool TryGetKeyword(string keyword, out List<Keyword> result)
        {
            return keywords.TryGetValue(keyword, out result);
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

        public static bool TryExecuteKeyword(string keywordName, IEnumerable<Keyword> keywords, string[] arguments, out object keywordResult)
        {
            foreach(var keyword in keywords)
            {
                object[] parsedArguments;
                if(!keyword.TryMatchArguments(arguments, out parsedArguments))
                {
                    continue;
                }

                Recorder.Instance.RecordEvent(keywordName, arguments);
                keywordResult = keyword.Execute(parsedArguments);
                return true;
            }
            keywordResult = null;
            return false;
        }

        private readonly Dictionary<string, List<Keyword>> keywords;
        private readonly Dictionary<Type, IRobotFrameworkKeywordProvider> objects;
    }
}

