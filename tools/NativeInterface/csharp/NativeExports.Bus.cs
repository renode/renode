//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Buffers.Binary;
using System.Runtime.InteropServices;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.NativeInterface;

public static unsafe partial class NativeExports
{
    /// <summary>
    /// Sends every access to the ExternalControlBusPeripheral named by machineName and peripheralName to native handlers.
    /// Calling it again for the same peripheral replaces its handlers.
    /// Each handler gets
    /// <list type="bullet">
    /// <item>The context pointer passed to this function</item>
    /// <item>The absolute bus address of the access</item>
    /// <item>The accessed bytes in little-endian order, which the read handler fills in</item>
    /// <item>How many bytes are accessed: 1, 2, 4 or 8 for CPU accesses, any number for bulk accesses</item>
    /// </list>
    /// Handlers run on the thread that makes the access, while the peripheral's bus lock is held.
    /// They may block, but must not call back into Renode. Any status other than RENODE_BUS_SUCCESS is logged as an error.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "renode_bus_set_handlers")]
    [return: DNNE.C99Type("RenodeStatus")]
    /// Keep RenodeBusStatus in sync with <see cref="NativeBusStatus" /> below.
    [DNNE.C99DeclCode("""
                      typedef enum RenodeBusStatus { RENODE_BUS_SUCCESS = 0, RENODE_BUS_ERROR = 1 } RenodeBusStatus;
                      typedef RenodeBusStatus (*RenodeBusReadHandler)(void *context, uint64_t address, uint8_t *data, uint32_t size);
                      typedef RenodeBusStatus (*RenodeBusWriteHandler)(void *context, uint64_t address, const uint8_t *data, uint32_t size);
                      """)]
    public static NativeStatus BusSetHandlers(
        [DNNE.C99Type("const char *")] byte* machineName,
        [DNNE.C99Type("const char *")] byte* peripheralName,
        [DNNE.C99Type("RenodeBusReadHandler")] delegate* unmanaged<void*, ulong, byte*, uint, NativeBusStatus> read,
        [DNNE.C99Type("RenodeBusWriteHandler")] delegate* unmanaged<void*, ulong, byte*, uint, NativeBusStatus> write,
        [DNNE.C99Type("void *")] void* context
    )
    {
        if(read == null || write == null)
        {
            Console.Error.WriteLine("Both read and write handlers are required");
            return NativeStatus.CommandError;
        }

        if(!Generics.TryGetPeripheral<ExternalControlBusPeripheral>(machineName, peripheralName, out var peripheral))
        {
            return NativeStatus.CommandError;
        }

        AttachBusHandlers(peripheral, read, write, context);
        return NativeStatus.Success;
    }

    private static void AttachBusHandlers(
        ExternalControlBusPeripheral peripheral,
        delegate* unmanaged<void*, ulong, byte*, uint, NativeBusStatus> readHandler,
        delegate* unmanaged<void*, ulong, byte*, uint, NativeBusStatus> writeHandler,
        void* context)
    {
        peripheral.OnReadByte = address => (byte)Read(address, sizeof(byte));
        peripheral.OnReadWord = address => (ushort)Read(address, sizeof(ushort));
        peripheral.OnReadDoubleWord = address => (uint)Read(address, sizeof(uint));
        peripheral.OnReadQuadWord = address => Read(address, sizeof(ulong));
        peripheral.OnReadBytes = ReadBytes;

        peripheral.OnWriteByte = (address, value) => Write(address, value, sizeof(byte));
        peripheral.OnWriteWord = (address, value) => Write(address, value, sizeof(ushort));
        peripheral.OnWriteDoubleWord = (address, value) => Write(address, value, sizeof(uint));
        peripheral.OnWriteQuadWord = (address, value) => Write(address, value, sizeof(ulong));
        peripheral.OnWriteBytes = WriteBytes;

        ulong Read(ulong address, int size)
        {
            byte* data = stackalloc byte[sizeof(ulong)];
            LogOnFailure(readHandler(context, address, data, (uint)size), "read", address, size);
            return BinaryPrimitives.ReadUInt64LittleEndian(new ReadOnlySpan<byte>(data, sizeof(ulong)));
        }

        byte[] ReadBytes(ulong address, int count)
        {
            var data = new byte[count];
            // Pin the array so the garbage collector cannot move it while the native handler uses the pointer.
            fixed(byte* pointer = data)
            {
                LogOnFailure(readHandler(context, address, pointer, (uint)count), "read", address, count);
            }
            return data;
        }

        void Write(ulong address, ulong value, int size)
        {
            byte* data = stackalloc byte[sizeof(ulong)];
            BinaryPrimitives.WriteUInt64LittleEndian(new Span<byte>(data, sizeof(ulong)), value);
            LogOnFailure(writeHandler(context, address, data, (uint)size), "write", address, size);
        }

        void WriteBytes(ulong address, byte[] array, int startingIndex, int count)
        {
            // Pin the array so the garbage collector cannot move it while the native handler uses the pointer.
            fixed(byte* pointer = array)
            {
                LogOnFailure(writeHandler(context, address, pointer + startingIndex, (uint)count), "write", address, count);
            }
        }

        void LogOnFailure(NativeBusStatus status, string access, ulong address, int size)
        {
            if(status != NativeBusStatus.Success)
            {
                peripheral.ErrorLog("Native {0} handler returned {1} for a {2}-byte access at 0x{3:X}", access, status, size, address);
            }
        }
    }

    /// <remarks>
    /// Keep in sync with RenodeBusStatus in the C99DeclCode attribute of <see cref="BusSetHandlers"/>.
    /// </remarks>
    public enum NativeBusStatus
    {
        Success = 0,
        Error = 1
    }
}
