*** Variables ***
${AGT_ELF}                          https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--agt.elf-s_391008-c0a91e7f3d279b86269ca83ac0aabb9936f94838
${SCI_UART_ELF}                     https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--sci_uart.elf-s_535224-63f8b0f8a025f09554a015f4b896f73b2cbeee43
${SCI_SPI_ELF}                      https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--sci_spi.elf-s_436396-52fced761b153c037fab56f23d65971e752af799
${SCI_I2C_ELF}                      https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--sci_i2c.elf-s_427784-2814fc53a441712e50d182c6e73770344b7f6ba4

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 using sysbus
    Execute Command                 mach create "ra8m1"

    Execute Command                 machine LoadPlatformDescription @platforms/boards/renesas-ek_ra8m1.repl

    Execute Command                 set bin @${elf}
    Execute Command                 macro reset "sysbus LoadELF $bin"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt  defaultPauseEmulation=${pauseEmulation}

Prepare LED Tester
    Create Led Tester               sysbus.port6.led_blue

Create Echo I2C Peripheral
    [Arguments]                     ${master}  ${slave_address}
    Execute Command                 machine LoadPlatformDescriptionFromString "dummy: Mocks.DummyI2CSlave @ ${master} ${slave_address}"

    ${python_script}=  Catenate     SEPARATOR=\n
    ...  python
    ...  """
    ...  class EchoI2CPeripheral:
    ...  ${SPACE*4}def __init__(self, dummy):
    ...  ${SPACE*8}self.dummy = dummy
    ...
    ...  ${SPACE*4}def write(self, data):
    ...  ${SPACE*8}self.dummy.EnqueueResponseBytes(data)
    ...
    ...  def mc_setup_echo_i2c_peripheral(path):
    ...  ${SPACE*4}dummy = monitor.Machine[path]
    ...  ${SPACE*4}dummy.DataReceived += EchoI2CPeripheral(dummy).write
    ...  """

    Execute Command                 ${python_script}
    Execute Command                 setup_echo_i2c_peripheral "sysbus.${master}.dummy"

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine                 ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT

    Execute Command                 agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester               0.001  defaultPauseEmulation=true

    # Configuration is roughly in ms
    Wait For Prompt On Uart         One-shot mode:
    Write Line To Uart              10  waitForEcho=false
    Wait For Line On Uart           Time period for one-shot mode timer: 10

    Wait For Prompt On Uart         Periodic mode:
    Write Line To Uart              5  waitForEcho=false
    Wait For Line On Uart           Time period for periodic mode timer: 5

    Wait For Prompt On Uart         Enter any key to start or stop the timers
    Write Line To Uart              waitForEcho=false

    # Timeout is extended by an additional 1ms to account for rounding errors
    Wait For Log Entry              AGT0 True  level=Error  timeout=0.011
    Wait For Log Entry              AGT0 False  level=Error
    # move to the beginning of a True state
    Assert Led State                True  timeout=0.01  pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking          testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State                True  timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart              waitForEcho=false
    Wait For Line On Uart           Periodic timer stopped. Enter any key to start timers.
    Assert And Hold Led State       True  0.0  0.05

Should Read And Write On UART
    Prepare Machine                 ${SCI_UART_ELF}
    Execute Command                 cpu AddHook `sysbus GetSymbolAddress "bsp_clock_init"` "cpu.PC = cpu.LR"

    Create Terminal Tester          sysbus.sci2

    Wait For Line On Uart           Starting UART demo

    Write Line To Uart              56  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 56
    Wait For Line On Uart           Set next value

    Write Line To Uart              1  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 1
    Wait For Line On Uart           Set next value

    Write Line To Uart              100  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 100
    Wait For Line On Uart           Set next value

    Write Line To Uart              371  waitForEcho=false
    Wait For Line On Uart           Invalid input. Input range is from 1 - 100

    Write Line To Uart              74  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 74
    Wait For Line On Uart           Set next value

Should Read Temperature From SPI
    Prepare Machine                 ${SCI_SPI_ELF}
    Execute Command                 cpu AddHook `sysbus GetSymbolAddress "bsp_clock_init"` "cpu.PC = cpu.LR"
    Prepare Segger RTT

    # Sample expects the MAX31723PMB1 temperature sensor which there is no model for in Renode
    Execute Command                 machine LoadPlatformDescriptionFromString "sensor: Sensors.GenericSPISensor @ sci2"

    # Sensor initialization values
    Execute Command                 sci2.sensor FeedSample 0x80
    Execute Command                 sci2.sensor FeedSample 0x6
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 15 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0xF
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 10 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0xA
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 2 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0x2
    Execute Command                 sci2.sensor FeedSample 0x0

    Wait For Line On Uart           Temperature:${SPACE*2}15.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}10.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}2.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}0.000000 *C

Should Pass Communication Test On SCI With Sample I2C Echo Slave
    Prepare Machine                 ${SCI_I2C_ELF}
    Prepare Segger RTT
    Execute Command                 cpu AddHook `sysbus GetSymbolAddress "bsp_clock_init"` "cpu.PC = cpu.LR"

    Create Echo I2C Peripheral      sci1  0x4A

    Wait For Line On Uart           ** SCI_I2C Master Write operation is successful **
    Wait For Line On Uart           ** SCI_I2C Master Read operation is successful **
    Wait For Line On Uart           ** Read and Write buffers are equal **
