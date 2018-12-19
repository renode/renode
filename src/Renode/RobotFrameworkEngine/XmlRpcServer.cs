//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using CookComputing.XmlRpc;
using Antmicro.Renode.Core;

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
        public XmlRpcStruct RunKeyword(string keywordName, string[] arguments)
        {
            var result = new XmlRpcStruct();
            var argumentsNotMatched = false;

            if(!keywordManager.TryGetKeyword(keywordName, out var keywords))
            {
                throw new XmlRpcFaultException(1, string.Format("Keyword \"{0}\" not found", keywordName));
            }
            try
            {
                if(KeywordManager.TryExecuteKeyword(keywordName, keywords, arguments, out var keywordResult))
                {
                    if(keywordResult != null)
                    {
                        result.Add(KeywordResultValue, keywordResult);
                    }
                    result.Add(KeywordResultStatus, KeywordResultPass);
                }
                else
                {
                    argumentsNotMatched = true;
                }
            }
            catch(Exception e)
            {
                result.Clear();

                result.Add(KeywordResultStatus, KeywordResultFail);
                result.Add(KeywordResultError, BuildRecursiveValueFromException(e, ex => ex.Message).StripNonSafeCharacters());
                result.Add(KeywordResultTraceback, BuildRecursiveValueFromException(e, ex => ex.StackTrace).StripNonSafeCharacters());
            }
            if(argumentsNotMatched)
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
                result.AppendFormat("{0}: {1}\n", e.GetType().Name, generator(e));
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

