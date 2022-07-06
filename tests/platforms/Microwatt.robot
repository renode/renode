*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode
${HELLO-WORLD}                microwatt--zephyr-hello_world.elf-s_296848-426bddb72e49a17eb03f8634baa0afe49f968b69
${MICROPYTHON}                microwatt--micropython.elf-s_2282296-072a8aac5d4d9897425f72ec2ca8ca123e6d624f

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/microwatt.repl

    Execute Command           sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Read Hello World
    Create Machine            ${HELLO-WORLD}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Hello World! microwatt

Should Start MicroPython
    Create Machine            ${MICROPYTHON}
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.cpu NIP 0
    Start Emulation

    Wait For Prompt On Uart   >>>

Should Perform Simple Mathematical Operation in MicroPython
    Create Machine            ${MICROPYTHON}
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.cpu NIP 0
    Start Emulation

    Wait For Prompt On Uart   >>>

    Write Line To Uart        7**3
    Wait For Line On Uart     343

Should Define And Execute Function in MicroPython
    Create Machine            ${MICROPYTHON}
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.cpu NIP 0
    Start Emulation

    Wait For Prompt On Uart   >>>

    Write Line To Uart        def fib(n):    
    Write Line To Uart        ${SPACE}if n < 2:
    Write Line To Uart        ${SPACE}${SPACE}return n
    Write Line To Uart        ${SPACE}else:
    Write Line To Uart        ${SPACE}${SPACE}return fib(n-1) + fib(n-2)
    Write Line To Uart

    Wait For Prompt On Uart   >>>

    Write Line To Uart        fib(19)
    Wait For Line On Uart     4181
