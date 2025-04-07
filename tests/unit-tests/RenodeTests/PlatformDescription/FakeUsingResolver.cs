//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.IO;

using Antmicro.Renode.PlatformDescription;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.UnitTests.PlatformDescription
{
    public sealed class FakeUsingResolver : IUsingResolver
    {
        public FakeUsingResolver()
        {
            argumentToSource = new Dictionary<string, string>();
            tempManager = TemporaryFilesManager.Instance;
            resultsCache = new Dictionary<string, string>();
        }

        public FakeUsingResolver With(string argument, string source)
        {
            argumentToSource.Add(argument, source);
            return this;
        }

        string IUsingResolver.Resolve(string argument, string includingFile)
        {
            string result;
            if(resultsCache.TryGetValue(argument, out result))
            {
                return result;
            }
            if(!argumentToSource.ContainsKey(argument))
            {
                return "nonExisting"; // necessary for the test with a non existing file
            }
            var tempFileName = tempManager.GetTemporaryFile();
            File.WriteAllText(tempFileName, argumentToSource[argument]);
            resultsCache[argument] = tempFileName;
            return tempFileName;
        }

        private readonly TemporaryFilesManager tempManager;
        private readonly Dictionary<string, string> argumentToSource;
        private readonly Dictionary<string, string> resultsCache;
    }
}