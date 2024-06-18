*** Variables ***
${UART}                             sysbus.uart
${BIN}                              @https://dl.antmicro.com/projects/renode/clic/clic_level_prio-01.elf-s_14364-35778c43e2c9ce51414fc232d1fd5c2a518d1847
${INT_ENABLE_ADDR}                  0x80002000
${PLATFORM}                         SEPARATOR=
...                                 """  ${\n}
...                                 using "tests/peripherals/CLIC/CLIC-test-platform.repl"  ${\n}
...                                 clic:  ${\n}
...                                 ${SPACE*4}machineLevelBits: 4  ${\n}
...                                 """

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${BIN}

*** Test Cases ***
Should Pass CLIC-level-prio-01
    Create Machine
    Create Terminal Tester          ${UART}
    Execute Command                 showAnalyzer uart Antmicro.Renode.Analyzers.LoggingUartAnalyzer

    Wait For Line On Uart           Init complete

    # Trigger interrupts 17 and 18; they have the same level, but 17 has a higher priority so it should be taken first.
    Execute Command                 clic OnGPIO 18 True
    Execute Command                 clic OnGPIO 17 True

    # Interrupts are disabled until a non-zero value is written to INT_ENABLE_ADDR.
    # This forces CLIC to prioritize the interrupts.
    Execute Command                 sysbus WriteByte ${INT_ENABLE_ADDR} 1

    # Interrupt with the highest priority should be handled first.
    Wait For Line On Uart           Interrupt 17, level 1, priority 15
    Wait For Line On Uart           Interrupt 18, level 1, priority 14

    # At this point we're spinning in interrupt 18 - preempt it with interrupt 16, that has a higher level.
    Execute Command                 clic OnGPIO 16 True
    Wait For Line On Uart           Interrupt 16, level 2, priority 12

    # At this point we're spinning in interrupt 16 - try to preempt it with interrupt of a lower level, but higher priority; this should not work.
    Execute Command                 clic OnGPIO 17 False
    Execute Command                 clic OnGPIO 17 True
    Should Not Be On Uart           Interrupt 17, level 1, priority 15
