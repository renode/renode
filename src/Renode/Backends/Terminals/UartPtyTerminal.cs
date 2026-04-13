//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;

using Antmicro.Migrant;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Utilities;

using AntShell.Terminal;

namespace Antmicro.Renode.Backends.Terminals
{
    public static class UartPtyTerminalExtensions
    {
        [SupportedRID("unix")]
        public static void CreateUartPtyTerminal(this Emulation emulation, string name, string fileName, bool forceCreate = false)
        {
            if(RuntimeInfo.IsWindows())
            {
                throw new RecoverableException("Creating UartPtyTerminal is not supported on Windows.");
            }
            emulation.ExternalsManager.AddExternal(new UartPtyTerminal(fileName, forceCreate), name);
        }
    }

    public class UartPtyTerminal : BackendTerminal, IDisposable
    {
        public UartPtyTerminal(string linkName, bool forceCreate = false)
        {
            this.linkName = linkName;
            this.forceCreate = forceCreate;

            Initialize();
        }

        public void Dispose()
        {
            io.Dispose();
            try
            {
                File.Delete(symlink);
            }
            catch(FileNotFoundException e)
            {
                throw new RecoverableException(string.Format("There was an error when removing symlink `{0}': {1}", symlink, e.Message));
            }
        }

        public override void WriteChar(byte value)
        {
            io.Write(value);
        }

        public override void BufferStateChanged(BufferState state)
        {
            base.BufferStateChanged(state);
            if(state == BufferState.Full)
            {
                io.Pause();
            }
            else if(state == BufferState.Empty)
            {
                io.Resume();
            }
        }

        [Migrant.Hooks.PostDeserialization]
        private void Initialize()
        {
            ptyStream = new PtyUnixStream();
            io = new IOProvider { Backend = new StreamIOSource(ptyStream) };
            io.ByteRead += b => CallCharReceived((byte)b);

            CreateSymlink();
        }

        private void CreateSymlink()
        {
            if(File.Exists(linkName))
            {
                if(!forceCreate)
                {
                    throw new RecoverableException(string.Format("File `{0}' already exists. Use forceCreate to overwrite it.", linkName));
                }

                try
                {
                    File.Delete(linkName);
                }
                catch(Exception e)
                {
                    throw new RecoverableException(string.Format("There was an error when removing existing `{0}' symlink: {1}", linkName, e.Message));
                }
            }
            try
            {
                symlink = File.CreateSymbolicLink(linkName, ptyStream.SlaveName).FullName;
            }
            catch(Exception e)
            {
                throw new RecoverableException(string.Format("There was an error when when creating a symlink `{0}': {1}", linkName, e.Message));
            }
        }

        [Transient]
        private PtyUnixStream ptyStream;
        [Transient]
        private IOProvider io;

        private string symlink;

        private readonly bool forceCreate;
        private readonly string linkName;
    }
}
