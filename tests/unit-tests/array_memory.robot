*** Variables ***
${URI}                                  @https://dl.antmicro.com/projects/renode
${BIN}                                  ${URI}/shell-demo-miv.elf-s_803248-ea4ddb074325b2cc1aae56800d099c7cf56e592a

${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}    SEPARATOR=\n
...                                     """
...                                     using "platforms/cpus/miv.repl"
...                                     // Unregister mapped memory
...                                     ddr: @none
...                                     // Register array memory and alias as ddr
...                                     ddr_array: Memory.ArrayMemory @ sysbus 0x80000000 as "ddr"
...                                     ${SPACE*4}size: 0x4000000
...                                     """

${PLATFORM_MIV_MIXED_OVERLAPPING}    SEPARATOR=\n
...                                     """
...                                     using "platforms/cpus/miv.repl"
...                                     ddr_overlay: Memory.ArrayMemory @ sysbus new Bus.BusPointRegistration { address: 0x80000000; cpu: cpu }
...                                     ${SPACE*4}size: 0x100
...                                     """

*** Keywords ***
Create Machine From Repl
    [Arguments]            ${repl_string}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${repl_string}
    Create Terminal Tester          sysbus.uart  timeout=1  defaultPauseEmulation=True

Zephyr Console Should Work
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              help

    Wait For Line On Uart           Please press the <Tab> button to see all available commands.
    Wait For Line On Uart           ou can also use the <Tab> button to prompt or auto-complete all commands or its subcommands.
    Wait For Line On Uart           You can try to call commands with <-h> or <--help> parameter for more information.

Ensure Mapped Memory Is Overlayed With Array Memory
    # Overlayed mapped memory area shouldn't be loaded with code
    ${res0}=  Execute Command       ddr ReadDoubleWord 0x0
    ${res1}=  Execute Command       sysbus ReadDoubleWord 0x80000000
    Should Be Equal                 ${res0}  ${res1}
    Should Contain                  ${res0}  0x00000000
    # Array memory overlay should be filled with code
    ${res2}=  Execute Command       ddr_overlay ReadDoubleWord 0x0
    ${res3}=  Execute Command       sysbus ReadDoubleWord 0x80000000 cpu
    Should Be Equal                 ${res2}  ${res3}
    Should Contain                  ${res2}  0x00000297

Write Hooks Program
    [Arguments]                     ${program_addr}  ${pc}=${program_addr}
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             nop  # Hook will be attached to this instruction
    ...                             loop:
    ...                                nop
    ...                                j loop
    Execute Command                 cpu AssembleBlock ${program_addr} "${program}"
    Execute Command                 cpu AddHook ${pc} "self.InfoLog('Hook Encountered')"
    Execute Command                 cpu PC ${pc}

*** Test Cases ***
Should Run Zephyr From Array Memory
    Create Machine From Repl        ${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}
    Execute Command                 sysbus LoadELF ${BIN}
    Zephyr Console Should Work

Should Execute From Mixed Memory Page
    Create Machine From Repl        ${PLATFORM_MIV_MIXED_OVERLAPPING}
    # cpu context passed to LoadELF command is important because of the CPU-specific overlay
    Execute Command                 sysbus LoadELF ${BIN} false cpu
    # ensure overlayed mapped memory was not loaded with code and therefore that program executes from the array memory overlay
    Ensure Mapped Memory Is Overlayed With Array Memory
    Zephyr Console Should Work

Should Not Repeat Hooks From Array Memory
    Create Machine From Repl        ${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}
    Write Hooks Program             0x80000000

    Create Log Tester               1  defaultPauseEmulation=true
    Wait For Log Entry              Hook Encountered
    Should Not Be In Log            Hook Encountered  # The hook should only be executed once

Should Not Repeat Hooks From Array Memory Using Virtual Addressing
    Create Machine From Repl        ${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}
    Write Hooks Program             0x81000000  0x80000000

    Execute Command                 cpu EnableExternalWindowMmu true
    ${window_index}=                Execute Command  cpu AcquireExternalMmuWindow 7  # 7 - rwx permissions
    Execute Command                 cpu SetMmuWindowStart ${window_index} 0x80000000
    Execute Command                 cpu SetMmuWindowEnd ${window_index} 0x80001000
    Execute Command                 cpu SetMmuWindowAddend ${window_index} 0x1000000
    Execute Command                 cpu SetMmuWindowPrivileges ${window_index} 7  # 7 - rwx permissions

    Create Log Tester               1  defaultPauseEmulation=true
    Wait For Log Entry              Hook Encountered
    Should Not Be In Log            Hook Encountered  # The hook should only be executed once
