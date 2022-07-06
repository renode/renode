*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode
${PROMPT}                     litex>${SPACE}

*** Keywords ***
Create Machine
    [Arguments]  ${bin}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/crosslink-nx-evn.repl

    Execute Command          sysbus LoadBinary ${URI}/${bin} 0x0
    Execute Command          sysbus.cpu PC 0x0

Assert Led
    [Arguments]  ${id}  ${expected_state}

    ${actual_state}=  Execute Command  sysbus.leds.led${id} State
    Should Be Equal   ${expected_state}  ${actual_state.rstrip()}

*** Test Cases ***
Should Run LiteX BIOS
    Create Machine           crosslink-nx-evn_litex_bios.bin-s_22272-5c9b575eac0a1b12e62860c0c8904dd4d7181279
    Create Terminal Tester   ${UART}

    Start Emulation

    Wait For Line On Uart    BIOS CRC passed
    Wait For Line On Uart    CPU:\\s+VexRiscv                  treatAsRegex=true
    Wait For Line On Uart    === Boot ===
    Wait For Line On Uart    === Console ===

    Wait For Prompt On Uart  ${PROMPT} 

    Write Line To Uart       help

    Wait For Line On Uart    LiteX BIOS, available commands

    Wait For Prompt On Uart  ${PROMPT} 

    Assert Led               0  False

    Write Line To Uart       leds 0x1
    Wait For Prompt On Uart  ${PROMPT} 

    Assert Led               0  True

