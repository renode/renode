*** Variables ***
${UART}                       sysbus.sercom3
${ELF}                        @https://dl.antmicro.com/projects/renode/adafruit_itsybitsy_m4_express-zephyr-shell_module.elf-s_1174688-96ba3690738a878b9f1d47e5ac677592a42c9040
${PLATFORM}                   @platforms/cpus/atsamd51g19a.repl
${PROMPT}                     uart:~$

*** Keywords ***
Create Machine
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription ${PLATFORM} 
    Execute Command           sysbus LoadELF ${ELF} 

*** Test Cases ***
Should Boot Shell
    Create Machine
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        help 
    Wait For Line On Uart     Please press the <Tab> button to see all available commands.
    Wait For Prompt On Uart   ${PROMPT}
