//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Migrant;
using Antmicro.Renode.Logging;

using AntShell.Terminal;

using TermSharp;
using TermSharp.Vt100;

namespace Antmicro.Renode.UI
{
    [Transient]
    public class TerminalIOSource : IActiveIOSource, IDisposable
    {
        public TerminalIOSource(Terminal terminal)
        {
            vt100decoder = new TermSharp.Vt100.Decoder(terminal, b => HandleInput(b), new TerminalToRenodeLogger(terminal));
            utfDecoder = new ByteUtf8Decoder(x => ApplicationExtensions.InvokeInUIThread(() => vt100decoder.Feed(x)));
        }

        public void Dispose()
        {
            HandleInput(-1);
        }

        public void Flush()
        {
            // do nothing
        }

        public void Pause()
        {
            // Required by IActiveIOSource interface
        }

        public void Resume()
        {
            // Required by IActiveIOSource interface
        }

        public void Write(byte b)
        {
            BeforeWrite?.Invoke(b);
            utfDecoder.Feed(b);
        }

        public void HandleInput(int b)
        {
            var br = ByteRead;
            if(br != null)
            {
                br(b);
            }
        }

        public bool IsAnythingAttached { get { return ByteRead != null; } }

        public event Action<int> ByteRead;

        public event Action<byte> BeforeWrite;

        private readonly TermSharp.Vt100.Decoder vt100decoder;
        private readonly ByteUtf8Decoder utfDecoder;

        private class TerminalToRenodeLogger : IDecoderLogger
        {
            public TerminalToRenodeLogger(Terminal t)
            {
                terminal = t;
            }

            public void Log(string format, params object[] args)
            {
                Logger.LogAs(terminal, LogLevel.Warning, format, args);
            }

            private readonly Terminal terminal;
        }
    }
}