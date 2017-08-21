﻿//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using AntShell.Terminal;
using TermSharp;
using TermSharp.Vt100;
using Emul8.Logging;
using Emul8.CLI;

namespace Antmicro.Renode.UI
{
    internal class TerminalIOSource : IActiveIOSource, IDisposable
    {
        public TerminalIOSource(Terminal terminal)
        {
            vt100decoder = new TermSharp.Vt100.Decoder(terminal, b => HandleInput(b), new TerminalToRenodeLogger(terminal));
            utfDecoder = new ByteUtf8Decoder(vt100decoder.Feed);
        }

        public void Dispose()
        {
            HandleInput(-1);
        }

        public void Flush()
        {
            // do nothing
        }

        public void Write(byte b)
        {
            ApplicationExtensions.InvokeInUIThread(() => utfDecoder.Feed(b));
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

