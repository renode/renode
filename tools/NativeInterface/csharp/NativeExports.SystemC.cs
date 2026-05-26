//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Runtime.InteropServices;

using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.SystemC;

namespace Antmicro.Renode.NativeInterface
{
    public static unsafe partial class NativeExports
    {
        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_send_backward_request")]
        [DNNE.C99DeclCode("""
/*
_RENODE_BRIDGE_H should be defined manually
after including renode_bridge.h
and before including librenode.h
to replace the stub below with the actual type.
See renode_bridge.cpp for an example.
We do not guarantee type safety,
it's just to make a compiler happy.
Enum renode_action from renode_bridge.h
is replaced with uint8_t to define an exact width.
*/
#ifndef _RENODE_BRIDGE_H
struct renode_message {
  uint8_t action;
  uint8_t data_length;
  uint8_t connection_index;
  uint64_t address;
  uint64_t payload;
};
#endif // _RENODE_BRIDGE_H
""")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCSendBackwardRequest(
            [DNNE.C99Type("struct renode_message")] RenodeMessage message,
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            try
            {
                systemC.HandleBackwardRequestFromNative(message);
                return NativeStatus.Success;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_send_forward_response")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCSendForwardResponse(
            [DNNE.C99Type("struct renode_message")] RenodeMessage message,
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            try
            {
                systemC.HandleForwardResponseFromNative(message);
                return NativeStatus.Success;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_send_forward_response_dmi")]
        [DNNE.C99DeclCode("""
/*
_RENODE_BRIDGE_H should be defined manually
after including renode_bridge.h
and before including librenode.h
to replace the stub below with the actual type.
See renode_bridge.cpp for an example.
*/
#ifndef _RENODE_BRIDGE_H
struct dmi_native_message {
  uint8_t action;
  uint8_t dmi_access;
  uint64_t start_address;
  uint64_t end_address;
  uint64_t pointer;
};
#endif // _RENODE_BRIDGE_H
""")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCSendForwardResponseDmi(
            [DNNE.C99Type("struct dmi_native_message")] DMINativeMessage message,
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            try
            {
                systemC.HandleForwardResponseDmiFromNative(message);
                return NativeStatus.Success;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_setup_renode_bridge")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCSetupRenodeBridge(
            [DNNE.C99Type("void*")] void* renodeBridgeRef,
            [DNNE.C99Type("void*")] delegate* unmanaged<void*, RenodeMessage, void> bwResponseHandler,
            [DNNE.C99Type("void*")] delegate* unmanaged<void*, DMIMessage, void> bwResponseDmiHandler,
            [DNNE.C99Type("void*")] delegate* unmanaged<void*, RenodeMessage, void> fwRequestHandler,
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            systemC.RenodeBridgeRef = renodeBridgeRef;
            systemC.SendBackwardResponseNative = bwResponseHandler;
            systemC.SendBackwardResponseDmiNative = bwResponseDmiHandler;
            systemC.SendForwardRequestNative = fwRequestHandler;

            return NativeStatus.Success;
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_init_native_connection")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCInitNativeConnection(
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            try
            {
                if(systemC.TryInitNativeConnection())
                {
                    return NativeStatus.Success;
                }
                else
                {
                    return NativeStatus.CommandError;
                }
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "renode_systemc_teardown_native_connection")]
        [return: DNNE.C99Type("RenodeStatus")]
        public static NativeStatus SystemCTeardownNativeConnection(
            [DNNE.C99Type("const char *")] byte* machName,
            [DNNE.C99Type("const char *")] byte* periName
        )
        {
            if(!TryGetSystemCHandle(machName, periName, out var systemC))
            {
                return NativeStatus.CommandError;
            }

            try
            {
                systemC.TeardownNativeConnection();
                return NativeStatus.Success;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine($"Exception: {ex}");
                return NativeStatus.Exception;
            }
        }

        private static bool TryGetSystemCHandle(byte* machName, byte* periName, out ISystemCNativeConnection systemC)
        {
            systemC = null;

            var machineName = Marshal.PtrToStringUTF8((IntPtr)machName);
            var peripheralName = Marshal.PtrToStringUTF8((IntPtr)periName);

            if(string.IsNullOrEmpty(machineName) || string.IsNullOrEmpty(peripheralName))
            {
                return false;
            }

            if(EmulationManager.Instance == null)
            {
                Console.Error.WriteLine("Emulation Manager instance is not initialized");
                return false;
            }

            var e = EmulationManager.Instance.CurrentEmulation;

            if(!e.TryGetMachineByName(machineName, out var m))
            {
                Console.Error.WriteLine($"No machine with name {machineName}");
                return false;
            }

            if(!m.TryGetByName<SystemCPeripheral>(peripheralName, out var p))
            {
                Console.Error.WriteLine($"No peripheral with name {peripheralName}");
                return false;
            }

            systemC = p;

            return true;
        }
    }
}
