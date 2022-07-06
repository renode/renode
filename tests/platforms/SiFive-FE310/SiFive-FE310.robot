*** Variables ***
${CPU}                        sysbus.cpu
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode
${SCRIPT}                     ${CURDIR}/../../../scripts/single-node/sifive_fe310.resc

*** Test Cases ***
Should Run Shell
    [Documentation]           Runs Zephyr's 'shell' sample on SiFive Freedom E310 platform.
    [Tags]                    zephyr  uart  interrupts
    Execute Command           $bin = ${URI}/zephyr-fe310-shell.elf-s_323068-cf87169150ecdb30ad5a14c87ae209c53dd3eca2
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}  endLineOption=TreatCarriageReturnAsEndLine
    Start Emulation

    Wait For Prompt On Uart   shell>
    # this sleep here is to prevent against writing to soon on uart - it can happen under high stress of the host CPU - when an uart driver is not initalized which leads to irq-loop
    Sleep                     3
    Write Line To Uart        select sample_module
    Wait For Prompt On Uart   sample_module>
    Write Line To Uart        ping
    Wait For Line On Uart     pong
