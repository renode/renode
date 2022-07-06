*** Settings ***
Documentation                 Testing the NXP K64F platform

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/nxp-k6xf.repl

    Execute Command           sysbus LoadELF ${URI}/${elf}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Run Zephyr Tests for UART
    [Documentation]           Runs Zephyr's basic uart tests
    Create Machine            nxp_k64f--zephyr_basic_uart.elf-s_618844-2d588c6899efaae76a7a27136fd8cff667bbcb6f

    Start Emulation
    Wait For Line On Uart     Please send characters to serial console    
    Write Line To Uart        The quick brown fox jumps over the lazy dog
    Wait For Line On Uart     Please send characters to serial console    
    Write Line To Uart        The quick brown fox jumps over the lazy dog
    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Run Zephyr Tests for TCP
    [Documentation]           Runs Zephyr's tests from tests/net/tcp
    Create Machine            nxp_k64f--zephyr_net_tcp.elf-s_1591188-15ce42eb41454d94762cc6bde77bc61f22dfcb26

    Start Emulation
    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL
