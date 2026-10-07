//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;

namespace Antmicro.Renode.NativeInterface;

public static unsafe partial class NativeExports
{
    /// <summary>
    /// Stores in <paramref name="machine"/> a handle to the machine named <paramref name="machineName"/>,
    /// or NULL if there is no such machine.
    /// Free the handle with renode_free_machine.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_get_machine")]
    [DNNE.C99DeclCode("typedef struct RenodeMachine RenodeMachine;")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus GetMachine(
        [DNNE.C99Type("const char *")] byte* machineName,
        [DNNE.C99Type("RenodeMachine **")] IntPtr* machine
    )
    {
        *machine = IntPtr.Zero;
        if(!Generics.TryGetMachine(machineName, out var machineInstance))
        {
            return NativeStatus.CommandError;
        }

        *machine = GCHandle.ToIntPtr(GCHandle.Alloc(machineInstance));
        return NativeStatus.Success;
    }

    /// <summary>
    /// Frees a handle from renode_get_machine. Does nothing if <paramref name="machine"/> is NULL.
    /// Handles to the machine's peripherals stay valid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_free_machine")]
    public static void FreeMachine([DNNE.C99Type("RenodeMachine *")] IntPtr machine)
    {
        if(machine != IntPtr.Zero)
        {
            GCHandle.FromIntPtr(machine).Free();
        }
    }
}
