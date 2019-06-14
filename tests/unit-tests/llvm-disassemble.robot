*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
Disassemble Block
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/boards/versatile.repl
    Execute Command           sysbus.cpu DisassembleBlock `sysbus.cpu PC`

