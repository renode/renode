#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

def mc_setup_segger_rtt(console, with_has_key = True, with_read = True, with_has_data = False):
    # `mc_` is omitted as it isn't needed in the Monitor.
    setup_arg_spec = 'setup_segger_rtt(console, with_has_key = True, with_read = True, with_has_data = False)'
    bus = monitor.Machine.SystemBus

    def has_data(cpu, _):
        cpu.SetRegisterUlong(0, 1 if console.Contains(ord('\r')) else 0)
        cpu.PC = cpu.LR

    def read(cpu, _):
        buffer = cpu.GetRegister(1).RawValue
        size = cpu.GetRegister(2).RawValue
        written = console.WriteBufferToMemory(buffer, size, cpu)
        cpu.SetRegisterUlong(0, written)
        cpu.PC = cpu.LR

    def write(cpu, _):
        pointer = cpu.GetRegister(1).RawValue
        length = cpu.GetRegister(2).RawValue
        for i in range(length):
            console.DisplayChar(bus.ReadByte(pointer + i))

        cpu.SetRegisterUlong(0, length)
        cpu.PC = cpu.LR

    def add_hook(symbol, function, argument_name = None):
        for cpu in bus.GetCPUs():
            found, addresses = bus.TryGetAllSymbolAddresses(symbol, context=cpu)

            if not found:
                cpu.WarningLog("Symbol '{}' not found. Make sure the binary is loaded before calling setup_segger_rtt"
                              .format(symbol))
                if argument_name is not None:
                    cpu.WarningLog("Adding this hook can be omitted by passing False to the optional '{}' argument:\n{}"
                                  .format(argument_name, setup_arg_spec))

            for address in addresses:
                cpu.AddHook(address, function)

    if with_has_key:
        add_hook("SEGGER_RTT_HasKey", has_data, "with_has_key")
    if with_has_data:
        add_hook("SEGGER_RTT_HasData", has_data, "with_has_data")
    if with_read:
        add_hook("SEGGER_RTT_ReadNoLock", read, "with_read")
    add_hook("SEGGER_RTT_WriteNoLock", write)
