*** Variables ***
${UART}                       sysbus.lpuart1
${PLATFORM}                   @platforms/cpus/stm32g474.repl
${URI}                        @https://dl.antmicro.com/projects/renode
# A bare-metal test (SYSCLK 170 MHz from HSI16 through the PLL, LPUART1 output,
# SysTick at 1 kHz); its source is in the pull request that added this file.
${ELF}                        ${URI}/stm32g474--bare_metal-hello.elf-s_9076-5299c733ac07927400bfea80a8f8b40cf53aadd4

*** Keywords ***
Create Machine
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription ${PLATFORM}
    Execute Command           sysbus LoadELF ${ELF}

*** Test Cases ***
Should Print Hello On LPUART1
    Create Machine
    Create Terminal Tester    ${UART}
    Start Emulation
    Wait For Line On Uart     Hello from STM32G474

Should Count SysTick At 1 kHz From The 170 MHz PLL
    Create Machine
    Create Terminal Tester    ${UART}
    Start Emulation
    Wait For Line On Uart     uptime 1 s    timeout=2
    Wait For Line On Uart     uptime 2 s    timeout=2
    ${t}=  Execute Command    machine GetTimeSourceInfo
    Should Contain            ${t}    Elapsed Virtual Time: 00:00:02
