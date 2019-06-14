*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${CPU}                        sysbus.cpu
${UART}                       sysbus.uart
${URI}                        @http://antmicro.com/projects/renode
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/picosoc.resc

*** Test Cases ***
Should Run Sample Binary
    [Documentation]           Runs a demo application on PicoSoC platform
    [Tags]                    riscv  uart
    Execute Command           $bin = ${URI}/icebreaker_fw.elf-s_14080-c09a99cd3716d6428af7700e19af66d7935ea438
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}  Command>
    Start Emulation

    Wait For Line On Uart     Press ENTER to continue..
    Write Line To Uart
    Wait For Prompt On Uart
