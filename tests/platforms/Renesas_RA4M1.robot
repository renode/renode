*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode
${SHELL_ELF}            arduino_uno_r4_minima-zephyr-shell_module.elf-s_1068728-aab68bf55c34638d1ba641464a8456a04bfff1df
${GPT_ELF}              gpt_ek_ra4m1_ep.elf-s_765644-1d962f940be6f73024384883e7d6322a2a269ce0
${SEGGER_RTT_SETUP}     SEPARATOR=\n
...  """
...  def mc_setup_segger(name):
...  ${SPACE*4}segger = monitor.Machine[name]
...  ${SPACE*4}cpu = monitor.Machine["sysbus.cpu"]
...  ${SPACE*4}bus = monitor.Machine.SystemBus
...
...  ${SPACE*4}def store_char(cpu, _):
...  ${SPACE*4}${SPACE*4}segger.DisplayChar(cpu.GetRegisterUnsafe(1).RawValue)
...
...  ${SPACE*4}def has_key(cpu, _):
...  ${SPACE*4}${SPACE*4}cpu.SetRegisterUnsafeUlong(0, 0 if segger.IsEmpty() else 1)
...  ${SPACE*4}${SPACE*4}cpu.PC = cpu.GetRegisterUnsafe(14)
...
...  ${SPACE*4}def read(cpu, _):
...  ${SPACE*4}${SPACE*4}buffer = cpu.GetRegisterUnsafe(1).RawValue
...  ${SPACE*4}${SPACE*4}size = cpu.GetRegisterUnsafe(2).RawValue
...  ${SPACE*4}${SPACE*4}written = segger.WriteBufferToMemory(buffer, size, cpu)
...  ${SPACE*4}${SPACE*4}cpu.SetRegisterUnsafeUlong(0, written)
...  ${SPACE*4}${SPACE*4}cpu.PC = cpu.GetRegisterUnsafe(14)
...
...  ${SPACE*4}cpu.AddHook(bus.GetSymbolAddress("_StoreChar"), store_char)
...  ${SPACE*4}cpu.AddHook(bus.GetSymbolAddress("SEGGER_RTT_HasKey"), has_key)
...  ${SPACE*4}cpu.AddHook(bus.GetSymbolAddress("SEGGER_RTT_Read"), read)
...  """

*** Keywords ***
Prepare Machine
    [Arguments]                 ${bin}
    Execute Command             set bin @${URL}/${bin}
    Execute Command             include @scripts/single-node/arduino_uno_r4_minima.resc

Prepare UART Tester
    Create Terminal Tester      sysbus.sci2

Prepare Segger RTT
    Execute Command              machine CreateVirtualConsole "segger"
    Execute Command              python ${SEGGER_RTT_SETUP}
    Execute Command              setup_segger sysbus.segger

    Create Terminal Tester       sysbus.segger

*** Test Cases ***
Run ZephyrRTOS Shell
    Prepare Machine             ${SHELL_ELF}
    Prepare UART Tester

    Start Emulation
    Wait For Prompt On Uart     uart:~$
    Write Line To Uart          demo ping
    Wait For Line On Uart       pong

Should Run The Timer In One Shot Mode
    Prepare Machine              ${GPT_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart      User Input:
    Write Line To Uart           3    waitForEcho=false

    Wait For Line On Uart        Timer Expired in One-Shot Mode
