//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
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

        public bool TryMatchArguments(object[] arguments, out object[] parsedArguments)
        {
            var parameters = methodInfo.GetParameters();

            if(parameters.Length == 1 && parameters[0].ParameterType == typeof(string[])
                && arguments.All(a => a is string))
            {
                parsedArguments = new object[] { arguments.Select(a => (string)a).ToArray() };
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

        public Replay ReplayMode
        {
            get
            {
                var attr = methodInfo.GetCustomAttributes<RobotFrameworkKeywordAttribute>().Single();
                return attr.ReplayMode;
            }
        }

        private object ChangeType(object input, Type type)
        {
            var underlyingType = Nullable.GetUnderlyingType(type);
            if(underlyingType != null && input != null)
            {
                type = underlyingType;
            }
            return Convert.ChangeType(input, type);
        }

        private bool TryParseArguments(ParameterInfo[] parameters, object[] arguments, out object[] parsedArguments)
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
            foreach(var argumentObj in arguments)
            {
                int position;

                if(!(argumentObj is string))
                {
                    // Non-string arguments can only be positional
                    position = positionalArgumentIndex++;
                    args[position].IsParsed = true;
                    // Allow type conversions of non-string arguments to allow calling methods that
                    // take a float with a Python float which becomes a double on the C# side
                    args[position].Value = ChangeType(argumentObj, parameters[position].ParameterType);
                    continue;
                }

                var argument = (string)argumentObj;
                object result;
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