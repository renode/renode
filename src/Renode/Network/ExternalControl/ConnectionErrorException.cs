//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Exceptions;

namespace Antmicro.Renode.Network.ExternalControl
{
    public class ConnectionErrorException : RecoverableException
    {
        public ConnectionErrorException(Exception e)
            : base(e)
        {
        }
    }
}
