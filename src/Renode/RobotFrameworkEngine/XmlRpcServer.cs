//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

using Antmicro.Renode.Core;

using CookComputing.XmlRpc;

namespace Antmicro.Renode.RobotFramework
{
    internal class XmlRpcServer : XmlRpcListenerService, IDisposable
    {
        public XmlRpcServer(KeywordManager keywordManager)
        {
            this.keywordManager = keywordManager;
        }

        [XmlRpcMethod("get_keyword_names")]
        public string[] GetKeywordNames()
        {
            return keywordManager.GetRegisteredKeywords();
        }

        [XmlRpcMethod("run_keyword")]
        public XmlRpcStruct RunKeyword(string keywordName, object[] arguments)
        {
            var result = new XmlRpcStruct();
            KeywordManager.KeywordLookupResult lookupResult = default(KeywordManager.KeywordLookupResult);
            try
            {
                lookupResult = keywordManager.TryExecuteKeyword(keywordName, arguments, out var keywordResult);
                if(lookupResult == KeywordManager.KeywordLookupResult.Success)
                {
                    if(keywordResult != null)
                    {
                        if(keywordResult is string resultString)
                        {
                            keywordResult = Regex.Replace(resultString, "(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]", "", RegexOptions.Compiled);
                        }
                        else if(keywordResult is IList<object> list)
                        {
                            keywordResult = list.ToArray();
                        }
                        result.Add(KeywordResultValue, keywordResult);
                    }
                    result.Add(KeywordResultStatus, KeywordResultPass);
                }
            }
            catch(Exception e)
            {
                result.Clear();

                result.Add(KeywordResultStatus, KeywordResultFail);
                result.Add(KeywordResultError, BuildRecursiveValueFromException(e, ex => ex.Message).StripNonSafeCharacters());
                result.Add(KeywordResultTraceback, BuildRecursiveValueFromException(e, ex => ex.StackTrace).StripNonSafeCharacters());
            }
            if(lookupResult == KeywordManager.KeywordLookupResult.KeywordNotFound)
            {
                throw new XmlRpcFaultException(1, string.Format("Keyword \"{0}\" not found", keywordName));
            }
            if(lookupResult == KeywordManager.KeywordLookupResult.ArgumentsNotMatched)
            {
                throw new XmlRpcFaultException(2, string.Format("Arguments types do not match any available keyword \"{0}\" : [{1}]", keywordName, string.Join(", ", arguments)));
            }
            return result;
        }

        [XmlRpcMethod("stop_remote_server")]
        public void Dispose()
        {
            var robotFrontendEngine = (RobotFrameworkEngine)ObjectCreator.Instance.GetSurrogate(typeof(RobotFrameworkEngine));
            robotFrontendEngine.Shutdown();
        }

        private static string BuildRecursiveValueFromException(Exception e, Func<Exception, string> generator)
        {
            var result = new StringBuilder();
            while(e != null)
            {
                if(!(e is TargetInvocationException))
                {
                    // TargetInvocationException is only a container, it does not provide valuable information
                    result.AppendFormat("{0}: {1}\n", e.GetType().Name, generator(e));
                }
                e = e.InnerException;
            }

            return result.ToString();
        }

        private readonly KeywordManager keywordManager;

        private const string KeywordResultValue = "return";
        private const string KeywordResultStatus = "status";
        private const string KeywordResultError = "error";
        private const string KeywordResultTraceback = "traceback";

        private const string KeywordResultPass = "PASS";
        private const string KeywordResultFail = "FAIL";
    }
}