*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.usart0
${PROMPT}                     >

*** Keywords ***
Prepare Machine
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/boards/sltb004a.repl

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Run Baremetal CLI
    Prepare Machine
    Execute Command           sysbus LoadELF @https://dl.antmicro.com/projects/renode/sltb004a--gecko_sdk-cli_baremetal.out-s_705812-380134bce0235a1277d0568d55b3be97d91daf02

    Start Emulation

    Wait For Line On Uart     Started CLI Bare-metal Example

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        help
    Wait For Line On Uart     echo_str

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        echo_str test
    Wait For Line On Uart     <<echo_str command>>
    Wait For Line On Uart     test

