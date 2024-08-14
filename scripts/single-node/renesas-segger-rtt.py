#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

def mc_setup_segger_rtt(name):
    segger = monitor.Machine[name]
    bus = monitor.Machine.SystemBus
    cpus = bus.GetCPUs()

    def store_char(cpu, _):
        segger.DisplayChar(cpu.GetRegister(1).RawValue)

    def has_key(cpu, _):
        cpu.SetRegisterUlong(0, 1 if segger.Contains(ord('\r')) else 0)
        cpu.PC = cpu.LR

    def read(cpu, _):
        buffer = cpu.GetRegister(1).RawValue
        size = cpu.GetRegister(2).RawValue
        written = segger.WriteBufferToMemory(buffer, size, cpu)
        cpu.SetRegisterUlong(0, written)
        cpu.PC = cpu.LR

    def add_hook(symbol, function):
        for cpu in cpus:
            try:
                cpu.AddHook(bus.GetSymbolAddress(symbol), function)
            except:
                print "Failed to hook at '{}' for cpu {}".format(symbol, cpu.GetName())

    add_hook("_StoreChar", store_char)
    add_hook("SEGGER_RTT_HasKey", has_key)
    add_hook("SEGGER_RTT_Read", read)
