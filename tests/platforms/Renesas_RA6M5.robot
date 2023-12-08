*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode
${AGT_ELF}              renesas_ra6m5--agt.elf-s_303444-613fbe7bc11ecbc13afa7a8a907682bbbb2a3458

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

${LED_REPL}             SEPARATOR=\n
...  """
...  led: Miscellaneous.LED @ port6 10
...
...  port6:
...  ${SPACE*4}10 -> led@0
...  """

*** Keywords ***
Prepare Machine
    Execute Command             using sysbus
    Execute Command             mach create "ra6m5"

    Execute Command             machine LoadPlatformDescription @platforms/cpus/R7FA6M5B.repl

    Execute Command             set bin @${URL}/${AGT_ELF}
    Execute Command             macro reset "sysbus LoadELF $bin"
    Execute Command             runMacro $reset

Prepare Segger RTT
    Execute Command             machine CreateVirtualConsole "segger"
    Execute Command             python ${SEGGER_RTT_SETUP}
    Execute Command             setup_segger sysbus.segger
    Create Terminal Tester      sysbus.segger

Prepare LED Tester
    Execute Command             machine LoadPlatformDescriptionFromString ${LED_REPL}
    Create Led Tester           sysbus.port6.led

*** Test Cases ***
Should Run Periodicaly Blink LED
    Prepare Machine
    Prepare LED Tester
    Prepare Segger RTT

    Execute Command             agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester           0.001

    # Configuration is roughly in ms
    Wait For Prompt On Uart     One-shot mode:
    Write Line To Uart          10                                                      waitForEcho=false
    Wait For Line On Uart       Time period for one-shot mode timer: 10

    Wait For Prompt On Uart     Periodic mode:
    Write Line To Uart          5                                                       waitForEcho=false
    Wait For Line On Uart       Time period for periodic mode timer: 5

    Wait For Prompt On Uart     Enter any key to start or stop the timers
    Write Line To Uart                                                                  waitForEcho=false

    # Timeout is extended by an additional 1ms to account for rounding errors
    Wait For Log Entry          AGT0 True   level=Error    pauseEmulation=true  timeout=0.011
    Wait For Log Entry          AGT0 False  level=Error    pauseEmulation=true
    # move to the begining of a True state
    Assert Led State            True        timeout=0.01   pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking      testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State            True        timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart                                                                  waitForEcho=false
    Wait For Line On Uart       Periodic timer stopped. Enter any key to start timers.  pauseEmulation=true
    Assert And Hold Led State   True  0.0  0.05
