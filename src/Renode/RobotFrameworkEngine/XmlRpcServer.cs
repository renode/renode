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
using CookComputing.XmlRpc;
using Emul8.Core;

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

            List<Keyword> keywords;
            if(!keywordManager.TryGetKeyword(keywordName, out keywords))
            {
                throw new XmlRpcFaultException(1, string.Format("Keyword \"{0}\" not found", keywordName));
            }

            foreach(var keyword in keywords)
            {
                object[] parsedArguments;
                if(!keyword.TryMatchArguments(arguments, out parsedArguments))
                {
                    continue;
                }

                try
                {
                    Recorder.Instance.RecordEvent(keywordName, arguments);
                    var keywordResult = keyword.Execute(parsedArguments);
                    if(keywordResult != null)
                    {
                        result.Add(KeywordResultValue, keywordResult.ToString());
                    }
                    result.Add(KeywordResultStatus, KeywordResultPass);
                }
                catch(Exception e)
                {
                    result.Clear();

                    result.Add(KeywordResultStatus, KeywordResultFail);
                    result.Add(KeywordResultError, BuildRecursiveErrorMessage(e));
                    result.Add(KeywordResultTraceback, e.StackTrace);
                }

                return result;
            }

            throw new XmlRpcFaultException(2, string.Format("Arguments types do not match any available keyword \"{0}\" : [{1}]", keywordName, string.Join(", ", arguments)));
        }

        [XmlRpcMethod("stop_remote_server")]
        public void Dispose()
        {
            var robotFrontendEngine = (RobotFrameworkEngine)ObjectCreator.Instance.GetSurrogate(typeof(RobotFrameworkEngine));
            robotFrontendEngine.Shutdown();
        }

        private static string BuildRecursiveErrorMessage(Exception e)
        {
            var result = new StringBuilder();
            while(e != null)
            {
                result.AppendFormat("{0}: {1}\n", e.GetType().Name, e.Message);
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

