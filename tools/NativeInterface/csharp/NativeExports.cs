//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.UI;

using CommandInteractionEater = Antmicro.Renode.UserInterface.CommandInteractionEater;
using Monitor = Antmicro.Renode.UserInterface.Monitor;

namespace Antmicro.Renode.NativeInterface
{
    public static unsafe class NativeExports
    {
        [UnmanagedCallersOnly(EntryPoint = "renode_init")]
        /// Keep in sync with <see cref="NativeStatus" /> below.
        [DNNE.C99DeclCode("typedef enum RenodeStatus { RENODE_SUCCESS = 0, RENODE_COMMAND_ERROR = 1, RENODE_QUIT_REQUESTED = 2, RENODE_EXCEPTION = -1 } RenodeStatus;")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus Init([DNNE.C99Type("const char *")] byte* scriptPath, int telnetPort, int robotPort)
        {
            try
            {
                var script = scriptPath != (byte*)0 ? Marshal.PtrToStringUTF8((IntPtr)scriptPath) : null;

                var options = new Options
                {
                    DisableXwt = true,
                    HideAnalyzers = true,
                    FilePath = script,
                    Port = telnetPort,
                    HideMonitor = telnetPort < 0, // Don't try to show the GUI monitor if the telnet server is disabled
                    RobotFrameworkRemoteServerPort = robotPort,
                };

                EmulationManager.RebuildInstance();

                var renodeThread = new Thread(() =>
                {
                    Program.MainWithOptions(options);
                });
                renodeThread.Name = "Renode";
                renodeThread.Start();

                // Wait until the Monitor is registered
                do
                {
                    Thread.Sleep(50);
                    monitor = (Monitor)ObjectCreator.Instance.GetSurrogate(typeof(Monitor));
                } while(monitor == null);

                return NativeStatus.Success;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_exec_command")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus ExecCommand([DNNE.C99Type("const char *")] byte* cmd)
        {
            try
            {
                var command = Marshal.PtrToStringUTF8((IntPtr)cmd);
                var ok = monitor.Parse(command);

                if(monitor.Interaction.QuitEnvironment)
                {
                    return NativeStatus.QuitRequested;
                }
                return ok ? NativeStatus.Success : NativeStatus.CommandError;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_exec_command_ex")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus ExecCommandEx(
            [DNNE.C99Type("const char *")] byte* cmd,
            [DNNE.C99Type("char *")] byte* outBuf, int outSize,
            [DNNE.C99Type("char *")] byte* errBuf, int errSize)
        {
            try
            {
                var eater = new CommandInteractionEater();
                var command = Marshal.PtrToStringUTF8((IntPtr)cmd);
                var ok = monitor.Parse(command, eater);

                CopyStringToBuffer(eater.GetContents(), outBuf, outSize);
                CopyStringToBuffer(eater.GetError(), errBuf, errSize);

                if(eater.QuitEnvironment)
                {
                    return NativeStatus.QuitRequested;
                }
                return (ok && !eater.HasError) ? NativeStatus.Success : NativeStatus.CommandError;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        private static unsafe void CopyStringToBuffer(string text, byte* buf, int size)
        {
            if(buf == (byte*)0 || size <= 0)
            {
                return;
            }
            var bytes = System.Text.Encoding.UTF8.GetBytes(text ?? "");
            var count = Math.Min(bytes.Length, size - 1);
            if(count > 0)
            {
                Marshal.Copy(bytes, 0, (IntPtr)buf, count);
            }
            buf[count] = 0;
        }

        private static Monitor monitor;

        /// <remarks>
        /// Keep in sync with RenodeStatus in the C99DeclCode attribute of <see cref="Init"/>
        /// </remarks>
        public enum NativeStatus
        {
            Success = 0,
            CommandError = 1,
            QuitRequested = 2,
            Exception = -1
        }
    }
}
