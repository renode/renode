*** Variables ***
${URL}                        https://dl.antmicro.com/projects/renode
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
    Execute Command           sysbus LoadELF @${URL}/sltb004a--gecko_sdk-cli_baremetal.out-s_705812-380134bce0235a1277d0568d55b3be97d91daf02

    Start Emulation

    Wait For Line On Uart     Started CLI Bare-metal Example

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        help
    Wait For Line On Uart     echo_str

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        echo_str test
    Wait For Line On Uart     <<echo_str command>>
    Wait For Line On Uart     test

# Adapted from https://github.com/openthread/openthread/blob/255a326b10972097916e1bdc56e98851d625b271/tests/toranj/cli/test-001-get-set.py
Should Pass 001 Get Set Test
    Prepare Machine
    Execute Command           sysbus LoadELF @${URL}/efr32mg12--ot-cli-ftd.out-s_42829512-3b09a2a9e6b0794e1612e14119760ca1ff671e8b

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Write Line To Uart        channel 21
    Wait For Line On Uart     Done
    Write Line To Uart        channel
    Wait For Line On Uart     21
    Wait For Line On Uart     Done

    Write Line To Uart        extaddr 1122334455667788
    Wait For Line On Uart     Done
    Write Line To Uart        extaddr
    Wait For Line On Uart     1122334455667788
    Wait For Line On Uart     Done

    Write Line To Uart        extpanid 1020031510006016
    Wait For Line On Uart     Done
    Write Line To Uart        extpanid
    Wait For Line On Uart     1020031510006016
    Wait For Line On Uart     Done

    Write Line To Uart        networkkey 0123456789abcdeffecdba9876543210
    Wait For Line On Uart     Done
    Write Line To Uart        networkkey
    Wait For Line On Uart     0123456789abcdeffecdba9876543210
    Wait For Line On Uart     Done

    Write Line To Uart        panid 0xabba
    Wait For Line On Uart     Done
    Write Line To Uart        panid
    Wait For Line On Uart     0xabba
    Wait For Line On Uart     Done

    Write Line To Uart        mode rd
    Wait For Line On Uart     Done
    Write Line To Uart        mode
    Wait For Line On Uart     rd
    Wait For Line On Uart     Done

    Write Line To Uart        routerupgradethreshold 1
    Wait For Line On Uart     Done
    Write Line To Uart        routerupgradethreshold
    Wait For Line On Uart     1
    Wait For Line On Uart     Done

    Write Line To Uart        routerselectionjitter 100
    Wait For Line On Uart     Done
    Write Line To Uart        routerselectionjitter
    Wait For Line On Uart     100
    Wait For Line On Uart     Done

    Write Line To Uart        ifconfig
    Wait For Line On Uart     down
    Wait For Line On Uart     Done

    Write Line To Uart        state
    Wait For Line On Uart     disabled
    Wait For Line On Uart     Done
