#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

def mc_setup_segger_rtt(name, with_has_key = True, with_read = True):
    # `mc_` is omitted as it isn't needed in the Monitor.
    setup_arg_spec = 'setup_segger_rtt(name, with_has_key = True, with_read = True)'
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

        cpu.SetRegisterUlong(0, length)
        cpu.PC = cpu.LR

    def add_hook(symbol, function):
        for cpu in bus.GetCPUs():
            try:
                cpu.AddHook(bus.GetSymbolAddress(symbol, cpu), function)
            except Exception as e:
                cpu.WarningLog("Failed to add hook at '{}': {}".format(symbol, e))
                cpu.WarningLog("Make sure the binary is loaded before calling setup_segger_rtt")
                if function == has_key or function == read:
                    cpu.WarningLog("Adding this hook can be omitted by passing False to the optional 'with_{}' argument:\n{}"
                                  .format(function.__name__, setup_arg_spec))

    if with_has_key:
        add_hook("SEGGER_RTT_HasKey", has_key)
    if with_read:
        add_hook("SEGGER_RTT_ReadNoLock", read)
    add_hook("SEGGER_RTT_WriteNoLock", write)
