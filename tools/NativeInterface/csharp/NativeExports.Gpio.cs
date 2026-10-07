//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;

namespace Antmicro.Renode.NativeInterface;

public static unsafe partial class NativeExports
{
    /// <summary>
    /// Stores in <paramref name="gpio"/> a handle to the <see cref="IGPIOReceiver"/> named <paramref name="peripheralName"/>
    /// on the machine that <paramref name="machine"/> refers to, or NULL if there is no such peripheral.
    /// Free the handle with renode_free_gpio.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_get_gpio")]
    [DNNE.C99DeclCode("typedef struct RenodeGpio RenodeGpio;")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus GetGpio(
        [DNNE.C99Type("RenodeMachine *")] IntPtr machine,
        [DNNE.C99Type("const char *")] byte* peripheralName,
        [DNNE.C99Type("RenodeGpio **")] IntPtr* gpio
    )
    {
        *gpio = IntPtr.Zero;
        if(!Generics.TryGetPeripheral<IGPIOReceiver>(machine, peripheralName, out var receiver))
        {
            return NativeStatus.CommandError;
        }

        *gpio = GCHandle.ToIntPtr(GCHandle.Alloc(receiver));
        return NativeStatus.Success;
    }

    /// <summary>
    /// Sets GPIO input number <paramref name="id"/> to <paramref name="state"/>, on the peripheral that <paramref name="gpio"/> refers to.
    /// <paramref name="id"/> is the number passed to <see cref="IGPIOReceiver.OnGPIO"/>.
    /// The input changes on the calling thread, before this function returns.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_set_gpio_state")]
    [DNNE.C99DeclCode("#include <stdbool.h>")]
    [return: DNNE.C99Type("RenodeStatus")]
    public static NativeStatus SetGpioState(
        [DNNE.C99Type("RenodeGpio *")] IntPtr gpio,
        int id,
        // C# does not permit bool parameters in UnmanagedCallersOnly methods, and a C bool has the ABI of a byte.
        [DNNE.C99Type("bool")] byte state
    )
    {
        if(gpio == IntPtr.Zero)
        {
            return NativeStatus.CommandError;
        }

        var receiver = (IGPIOReceiver)GCHandle.FromIntPtr(gpio).Target;
        receiver.OnGPIO(id, state != 0);
        return NativeStatus.Success;
    }

    /// <summary>
    /// Frees a handle from renode_get_gpio. Does nothing if <paramref name="gpio"/> is NULL.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_free_gpio")]
    public static void FreeGpio([DNNE.C99Type("RenodeGpio *")] IntPtr gpio)
    {
        if(gpio != IntPtr.Zero)
        {
            GCHandle.FromIntPtr(gpio).Free();
        }
    }
}
