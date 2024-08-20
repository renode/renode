#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

def mc_setup_segger_rtt(name):
    segger = monitor.Machine[name]
    bus = monitor.Machine.SystemBus

    def has_key(cpu, _):
        cpu.SetRegisterUlong(0, 1 if segger.Contains(ord('\r')) else 0)
        cpu.PC = cpu.LR

    def read(cpu, _):
        buffer = cpu.GetRegister(1).RawValue
        size = cpu.GetRegister(2).RawValue
        written = segger.WriteBufferToMemory(buffer, size, cpu)
        cpu.SetRegisterUlong(0, written)
        cpu.PC = cpu.LR

    def write(cpu, _):
        pointer = cpu.GetRegister(1).RawValue
        length = cpu.GetRegister(2).RawValue
        for i in range(length):
            segger.DisplayChar(bus.ReadByte(pointer + i))

    def add_hook(symbol, function):
        for cpu in bus.GetCPUs():
            try:
                cpu.AddHook(bus.GetSymbolAddress(symbol), function)
            except Exception as e:
                cpu.WarningLog("Failed to add hook at '{}': {}".format(symbol, e))
                cpu.WarningLog("Make sure the binary is loaded before calling setup_segger_rtt")

    add_hook("SEGGER_RTT_HasKey", has_key)
    add_hook("SEGGER_RTT_Read", read)
    add_hook("SEGGER_RTT_WriteNoLock", write)
