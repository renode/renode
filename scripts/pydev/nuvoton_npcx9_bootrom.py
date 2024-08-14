#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

from array import array
import ctypes

from Antmicro.Renode.Peripherals.CPU import RegisterValue

try:
    # The additional CLR reference is required on dotnet
    clr.AddReference("System.Security.Cryptography.Algorithms")
except:
    pass

from System.Security.Cryptography import SHA256, SHA384, SHA512


def register_bootrom_hook(addr, func):
    self["sysbus.cpu"].AddHook(addr, func)
    # Fill the bootrom's function pointer entry with the address that the hook is registered to.
    # For simplicity hooks are added on function pointer locations, no the actual function addresses.
    self.SystemBus.WriteDoubleWord(addr, addr)
    self.InfoLog("Registering bootrom function at 0x{0:X}", addr)


# Based on: https://chromium.googlesource.com/chromiumos/platform/ec/+/6898a6542ed0238cc182948f56e3811534db1a38/chip/npcx/header.c#43
def register_bootloader():
    class FirmwareHeader(ctypes.LittleEndianStructure):
        _pack_ = 1
        _fields_ = [
            ("anchor", ctypes.c_uint32),
            ("ext_anchor", ctypes.c_uint16),
            ("spi_max_freq", ctypes.c_uint8),
            ("spi_read_mode", ctypes.c_uint8),
            ("cfg_err_detect", ctypes.c_uint8),
            ("fw_load_addr", ctypes.c_uint32),
            ("fw_entry", ctypes.c_uint32),
            ("err_detect_start_addr", ctypes.c_uint32),
            ("err_detect_end_addr", ctypes.c_uint32),
            ("fw_length", ctypes.c_uint32),
            ("flash_size", ctypes.c_uint8),
            ("reserved", ctypes.c_uint8 * 26),
            ("sig_header", ctypes.c_uint32),
            ("sig_fw_image", ctypes.c_uint32),
        ]

    HEADER_SIZE = ctypes.sizeof(FirmwareHeader)
    flash = self["sysbus.internal_flash"]

    def bootloader(cpu, addr):
        header_data = flash.ReadBytes(0x0, HEADER_SIZE)
        header = FirmwareHeader.from_buffer(array("B", header_data))

        firmware = flash.ReadBytes(HEADER_SIZE, header.fw_length)
        self.SystemBus.WriteBytes(firmware, header.fw_load_addr)

        cpu.PC = RegisterValue.Create(header.fw_entry, 32)

        self.InfoLog(
            "Firmware loaded at: 0x{0:X} ({1} bytes). PC = 0x{2:X}",
            header.fw_load_addr,
            header.fw_length,
            header.fw_entry,
        )

    register_bootrom_hook(0x0, bootloader)


# Based on:
# - https://chromium.googlesource.com/chromiumos/platform/ec/+/6898a6542ed0238cc182948f56e3811534db1a38/chip/npcx/trng.c
# - https://chromium.googlesource.com/chromiumos/platform/ec/+/6898a6542ed0238cc182948f56e3811534db1a38/chip/npcx/sha256_chip.c
def register_ncl_functions():
    DRGB_BASE_ADDRESS = 0x00000110
    SHA_BASE_ADDRESS = 0x0000013C

    POINTER_SIZE = 0x4

    DRBG_CONTEXT_SIZE = 240
    SHA_CONTEXT_SIZE = 212

    NCL_STATUS_OK = 0xA5A5
    NCL_STATUS_FAIL = 0x5A5A
    NCL_STATUS_INVALID_PARAM = 0x02

    NCL_SHA_TYPE_2_256 = 0
    NCL_SHA_TYPE_2_384 = 1
    NCL_SHA_TYPE_2_512 = 2

    def create_hook(name, return_value=NCL_STATUS_OK):
        def hook(cpu, addr):
            cpu.NoisyLog(
                "Entering '{0}' hook that returns 0x{1:X}", name, return_value
            )
            cpu.SetRegister(0, RegisterValue.Create(return_value, 32))
            cpu.PC = cpu.LR

        return hook

    rng = Antmicro.Renode.Core.PseudorandomNumberGenerator()

    def trng_generate(cpu, addr):
        out_buff = cpu.GetRegister(3).RawValue
        out_buff_len = self.SystemBus.ReadDoubleWord(cpu.SP.RawValue)

        data = System.Array[System.Byte](range(out_buff_len))
        rng.NextBytes(data)
        self.SystemBus.WriteBytes(data, out_buff)

        cpu.SetRegister(0, RegisterValue.Create(NCL_STATUS_OK, 32))
        cpu.PC = cpu.LR

    DRGB_FUNCTIONS = [
        create_hook("get_context_size", DRBG_CONTEXT_SIZE),
        create_hook("init_context"),
        create_hook("power"),
        create_hook("finalize_context"),
        create_hook("init"),
        create_hook("config"),
        create_hook("instantiate"),
        create_hook("uninstantiate"),
        create_hook("reseed"),
        trng_generate,
        create_hook("clear"),
    ]

    class SHAContext:
        sha_buffer = System.Collections.Generic.List[System.Byte]()
        sha_type = None

    def sha_start(cpu, addr):
        status = NCL_STATUS_OK
        sha_type = cpu.GetRegister(1).RawValue
        if sha_type in [
            NCL_SHA_TYPE_2_256,
            NCL_SHA_TYPE_2_384,
            NCL_SHA_TYPE_2_512,
        ]:
            SHAContext.sha_type = sha_type
        else:
            status = NCL_STATUS_INVALID_PARAM
        cpu.SetRegister(0, RegisterValue.Create(status, 32))
        cpu.PC = cpu.LR

    def sha_finish(cpu, addr):
        try:
            if SHAContext.sha_type == NCL_SHA_TYPE_2_256:
                sha_instance = SHA256.Create()
            elif SHAContext.sha_type == NCL_SHA_TYPE_2_384:
                sha_instance = SHA384.Create()
            elif SHAContext.sha_type == NCL_SHA_TYPE_2_512:
                sha_instance = SHA512.Create()
            else:
                cpu.SetRegister(
                    0, RegisterValue.Create(NCL_STATUS_FAIL, 32)
                )
                cpu.PC = cpu.LR
                return

            hash = sha_instance.ComputeHash(SHAContext.sha_buffer.ToArray())
            SHAContext.sha_buffer.Clear()

            data_addr = cpu.GetRegister(1).RawValue
            self.SystemBus.WriteBytes(hash, data_addr)

            cpu.SetRegister(0, RegisterValue.Create(NCL_STATUS_OK, 32))
            cpu.PC = cpu.LR
        finally:
            if sha_instance is not None:
                sha_instance.Dispose()

    def sha_update(cpu, addr):
        data_addr = cpu.GetRegister(1).RawValue
        length = cpu.GetRegister(2).RawValue
        data = self.SystemBus.ReadBytes(data_addr, length)

        SHAContext.sha_buffer.AddRange(data)

        cpu.SetRegister(0, RegisterValue.Create(NCL_STATUS_OK, 32))
        cpu.PC = cpu.LR

    SHA_FUNCTIONS = [
        create_hook("get_context_size", SHA_CONTEXT_SIZE),
        create_hook("init_context"),
        create_hook("finalize_context"),
        create_hook("init"),
        sha_start,
        sha_update,
        sha_finish,
        create_hook("calc"),
        create_hook("power"),
        create_hook("reset"),
    ]

    for base, collection in [
        (DRGB_BASE_ADDRESS, DRGB_FUNCTIONS),
        (SHA_BASE_ADDRESS, SHA_FUNCTIONS),
    ]:
        for i, func in enumerate(collection):
            register_bootrom_hook(base + i * POINTER_SIZE, func)


# Based on: https://chromium.googlesource.com/chromiumos/platform/ec/+/6898a6542ed0238cc182948f56e3811534db1a38/chip/npcx/rom_chip.h
def register_download_from_flash():
    def download_from_flash(cpu, addr):
        src_offset = cpu.GetRegister(0).RawValue
        dest_addr = cpu.GetRegister(1).RawValue
        size = cpu.GetRegister(2).RawValue
        exe_addr = self.SystemBus.ReadDoubleWord(cpu.SP.RawValue)

        data = self["sysbus.internal_flash"].ReadBytes(src_offset, size)
        self.SystemBus.WriteBytes(data, dest_addr)

        cpu.PC = RegisterValue.Create(exe_addr, 32)

        cpu.InfoLog(
            "Downloading from flash offset 0x{0:X} to 0x{1:X} ({2} bytes) and jumping to 0x{3:X}",
            src_offset,
            dest_addr,
            size,
            exe_addr,
        )

    register_bootrom_hook(0x40, download_from_flash)


register_bootloader()
register_ncl_functions()
register_download_from_flash()
