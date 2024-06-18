*** Variables ***
${UART}                             sysbus.uart
${BIN}                              @https://dl.antmicro.com/projects/renode/clic/clic_priorities-01.elf-s_14324-be2a3b6105f51eaf9bc08752bea764bcc9aa0f37
${INT_ENABLE_ADDR}                  0x80002000
${PLATFORM}                         SEPARATOR=
...                                 """  ${\n}
...                                 using "tests/peripherals/CLIC/CLIC-test-platform.repl"  ${\n}
...                                 clic:  ${\n}
...                                 ${SPACE*4}machineLevelBits: 0  ${\n}
...                                 """

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${BIN}

*** Test Cases ***
Should Pass CLIC-priorities-01
    Create Machine
    Create Terminal Tester          ${UART}
    Execute Command                 showAnalyzer uart Antmicro.Renode.Analyzers.LoggingUartAnalyzer

    Wait For Line On Uart           Init complete

    # Trigger the three interrupts.
    Execute Command                 clic OnGPIO 16 True
    Execute Command                 clic OnGPIO 17 True
    Execute Command                 clic OnGPIO 18 True

    # Interrupts are disabled until a non-zero value is written to INT_ENABLE_ADDR.
    # This forces CLIC to prioritize the interrupts.
    Execute Command                 sysbus WriteByte ${INT_ENABLE_ADDR} 1

    # Interrupt with the highest priority should be handled first.
    Wait For Line On Uart           Interrupt 18, priority 3 
    Wait For Line On Uart           Interrupt 16, priority 2
    Wait For Line On Uart           Interrupt 17, priority 1
