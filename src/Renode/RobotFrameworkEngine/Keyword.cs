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
using System.Text.RegularExpressions;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.RobotFramework
{
    internal class Keyword
    {
        public Keyword(KeywordManager manager, MethodInfo info)
        {
            this.manager = manager;
            methodInfo = info;
        }

        public bool TryMatchArguments(string[] arguments, out object[] parsedArguments)
        {
            var parameters = methodInfo.GetParameters();

            if(parameters.Length == 1 && parameters[0].ParameterType == typeof(string[]))
            {
                parsedArguments = new object[] { arguments };
                return true;
            }

            return TryParseArguments(parameters, arguments, out parsedArguments);
        }

        public object Execute(object[] arguments)
        {
            var obj = manager.GetOrCreateObject(methodInfo.DeclaringType);
            return methodInfo.Invoke(obj, arguments);
        }

        public int NumberOfArguments
        {
            get
            {
                return methodInfo.GetParameters().Length;
            }
        }

        public bool ShouldNotBeReplayed
        {
            get
            {
                var attr = methodInfo.GetCustomAttributes<RobotFrameworkKeywordAttribute>().Single();
                return attr.ShouldNotBeReplayed;
            }
        }

        private bool TryParseArguments(ParameterInfo[] parameters, string[] arguments, out object[] parsedArguments)
        {
            parsedArguments = null;
            if(arguments.Length > parameters.Length)
            {
                return false;
            }

            var args = new ArgumentDescriptor[parameters.Length];

            var positionalArgumentIndex = 0;
            var namedArgumentDetected = false;
            var pattern = new Regex(@"^([a-zA-Z0-9_]+)=(.+)");
            foreach(var argument in arguments)
            {
                object result;
                int position;
                string valueToParse;
                // check if it's a named argument
                var m = pattern.Match(argument);
                if(m.Success)
                {
                    namedArgumentDetected = true;
                    var name = m.Groups[1].Value;
                    var param = parameters.SingleOrDefault(x => x.Name == name);

                    if(param == null)
                    {
                        return false;
                    }

                    if(args[param.Position].IsParsed)
                    {
                        throw new ArgumentException("Named argument `{0}' specified multiple times", name);
                    }

                    position = param.Position;
                    valueToParse = m.Groups[2].Value;
                }
                else
                {
                    if(namedArgumentDetected)
                    {
                        // this is a serious error
                        throw new ArgumentException("Named arguments must appear after the positional arguments");
                    }

                    position = positionalArgumentIndex++;
                    valueToParse = argument;
                }

                if(!SmartParser.Instance.TryParse(valueToParse, parameters[position].ParameterType, out result))
                {
                    return false;
                }

                args[position].IsParsed = true;
                args[position].Value = result;
            }

            for(var i = 0; i < args.Length; i++)
            {
                if(args[i].IsParsed)
                {
                    continue;
                }

                if(!parameters[i].HasDefaultValue)
                {
                    return false;
                }

                args[i].IsParsed = true;
                args[i].Value = parameters[i].DefaultValue;
            }

            parsedArguments = args.Select(x => x.Value).ToArray();
            return true;
        }

        private readonly MethodInfo methodInfo;
        private readonly KeywordManager manager;

        private struct ArgumentDescriptor
        {
            public bool IsParsed;
            public object Value;

        }
    }
}

