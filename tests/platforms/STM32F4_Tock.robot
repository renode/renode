*** Variables ***
${APP_URL}                      https://dl.antmicro.com/projects/renode/cortex_m4--tock-cxx_hello.tbf-s_16384-2bf6dfc3ffd2894bea56341901beec1e903c3135
${TOCK_URL}                     https://dl.antmicro.com/projects/renode/stm32f412gdiscovery--tock_kernel.elf-s_3392340-6da12cfcd5c4180b60ce7bf2ad32f019c9e8216e
${UART}                         sysbus.usart2

*** Keywords ***
Create Machine
    Execute Command             $bin=@${TOCK_URL}
    Execute Command             $app=@${APP_URL}
    Execute Command             include @scripts/single-node/stm32f4_tock.resc

*** Test Cases ***
Should Print Hello World
    Create Machine
    Create Terminal Tester      ${UART}
    Start Emulation

    Wait For Line On Uart       Initialization complete. Entering main loop

    Wait For Line On Uart       D2 says hello
    Wait For Line On Uart       D1 says hello

    Wait For Line On Uart       D2 says hello
    Wait For Line On Uart       D1 says hello

    Wait For Line On Uart       D2 says hello
    Wait For Line On Uart       D1 says hello
