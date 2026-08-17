//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.UI;
using Antmicro.Renode.Logging;

using CommandInteractionEater = Antmicro.Renode.UserInterface.CommandInteractionEater;
using Monitor = Antmicro.Renode.UserInterface.Monitor;

namespace Antmicro.Renode.NativeInterface
{
    public static unsafe partial class NativeExports
    {
        [UnmanagedCallersOnly(EntryPoint = "renode_init")]
        /// Keep in sync with <see cref="NativeStatus" /> below.
        [DNNE.C99DeclCode("typedef enum RenodeStatus { RENODE_SUCCESS = 0, RENODE_COMMAND_ERROR = 1, RENODE_QUIT_REQUESTED = 2, RENODE_EXCEPTION = -1 } RenodeStatus;")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus Init([DNNE.C99Type("const char *")] byte* scriptPath, int telnetPort, int robotPort)
        {
            try
            {
                SetupAssemblyResolution();
                InitRenode(scriptPath, telnetPort, robotPort);
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
                var eater = new CommandInteractionEater();
                var command = Marshal.PtrToStringUTF8((IntPtr)cmd);
                var ok = monitor.Parse(command, eater);

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

        /// <summary>
        /// Adds handler triggered on new log entry.
        /// The callback receives
        /// <list type="bullet">
        /// <item>Pointer earlier provided by the user through the opaque argument</item>
        /// <item>Level of the message</item>
        /// <item>Tick at which message happened</item>
        /// <item>Pointer to name of the object that wrote the log</item>
        /// <item>Pointer to the message</item>
        /// </list>
        /// Pointers will be freed after return from the callback.
        /// If NULL is provided as name pointer, default logger backend name is used.
        /// </summary>
        [UnmanagedCallersOnly(EntryPoint = "renode_add_logging_handler")]
        // Keep in sync with LogLevel
        [DNNE.C99DeclCode("""
                          typedef enum RenodeLogLevel { RENODE_LOG_LEVEL_NOISY = -1, RENODE_LOG_LEVEL_DEBUG = 0, RENODE_LOG_LEVEL_INFO = 1, RENODE_LOG_LEVEL_WARNING = 2, RENODE_LOG_LEVEL_ERROR = 3 } RenodeLogLevel;
                          typedef void (*RenodeLogHandler)(void*, RenodeLogLevel, long long int, char*, char*);
                          """)]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus AddLoggingHandler(
            [DNNE.C99Type("RenodeLogHandler")] delegate* unmanaged<void*, int, long, byte*, byte*, void> handler,
            [DNNE.C99Type("void *")] byte* opaque,
            [DNNE.C99Type("const char *")] byte* namePtr
        )
        {
            if(handler == null)
            {
                return NativeStatus.CommandError;
            }

            var nameString = DefaultNativeLoggerName;
            if(namePtr != null)
            {
                nameString = Marshal.PtrToStringUTF8((IntPtr)namePtr);
            }

            try
            {
                Logger.AddBackend(new NativeExportsBackend(handler, opaque), nameString);
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }

            return NativeStatus.Success;
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_remove_logging_handler")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus RemoveLoggingHandler(
            [DNNE.C99Type("const char *")] byte* namePtr
        )
        {
            var nameString = DefaultNativeLoggerName;
            if(namePtr != null)
            {
                nameString = Marshal.PtrToStringUTF8((IntPtr)namePtr);
            }

            var backends = Logger.GetBackends();
            if(!backends.TryGetValue(nameString, out var backend))
            {
                return NativeStatus.CommandError;
            }

            Logger.RemoveBackend(backend);
            return NativeStatus.Success;
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

        private static void SetupAssemblyResolution()
        {
            var thisDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

            // This DLL will always be in platform-lib/[RID] relative to the other DLLs, so we need to also look there
            var binDir = Path.Join(thisDir, "..", "..");
            AppDomain.CurrentDomain.AssemblyResolve += (_, ev) =>
            {
                var assemblyIdentifier = ev.Name.Split(',')[0];
                var assemblyPath = Path.Combine(binDir, assemblyIdentifier + ".dll");
                if(!Path.Exists(assemblyPath))
                {
                    return null;
                }
                var assembly = Assembly.LoadFrom(assemblyPath);
                return assembly;
            };
        }

        private static unsafe void InitRenode(byte* scriptPath, int telnetPort, int robotPort)
        {
            var script = scriptPath != (byte*)0 ? Marshal.PtrToStringUTF8((IntPtr)scriptPath) : null;

            var options = new Options
            {
                DisableXwt = true,
                HideAnalyzers = false,
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
        }

        private static Monitor monitor;

        private const string DefaultNativeLoggerName = "native";

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
