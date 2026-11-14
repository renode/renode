*** Variables ***
${FIRMWARE_URL}               https://dl.antmicro.com/projects/renode
${QUANTUM_TIME}               0.000020
${TESTER_TIMEOUT}             10
${ABSENCE_TIMEOUT}            1

*** Keywords ***
Create Emulation
    Execute Command           emulation SetGlobalSerialExecution true
    Execute Command           emulation SetQuantum "${QUANTUM_TIME}"
    Execute Command           emulation SetAdvanceImmediately true
    Execute Command           emulation CreateIEEE802_15_4Medium "wireless"

Create Node
    [Documentation]           Creates a board running ${elf} on the wireless medium and returns a tester
    ...                       on ${uart}. Each function in @{stubs} is skipped, returning 0.
    [Arguments]               ${name}  ${board}  ${elf}  ${uart}  @{stubs}  ${timeout}=${TESTER_TIMEOUT}  ${waitForEcho}=true
    Execute Command           mach create "${name}"
    Execute Command           machine LoadPlatformDescription @platforms/boards/silabs/${board}.repl
    Execute Command           sysbus LoadELF @${elf}
    FOR  ${stub}  IN  @{stubs}
        Execute Command       cpu AddHook `sysbus GetSymbolAddress "${stub}"` "cpu.SetRegisterUlong(0, 0); cpu.PC = cpu.LR"
    END
    ${vectors}=               Set Variable  cpu VectorTableOffset `sysbus GetSymbolAddress "__Vectors"`
    Execute Command           macro reset """sysbus LoadSymbolsFrom @${elf}${\n}${vectors}"""
    Execute Command           runMacro $reset
    Execute Command           connector Connect sysbus.radio wireless
    ${tester}=                Create Terminal Tester  sysbus.${uart}  machine=${name}  timeout=${timeout}
    ...                       defaultPauseEmulation=true  defaultWaitForEcho=${waitForEcho}
    RETURN                    ${tester}

Wait For
    [Documentation]           Waits for the ${pattern} regex on ${tester}, also matching an unfinished
    ...                       line unless ${endline} is set, and returns the matching line.
    [Arguments]               ${tester}  ${pattern}  ${timeout}=${None}  ${endline}=${False}
    IF  $timeout is None
        ${result}=            Wait For Line On Uart  ${pattern}  testerId=${tester}
        ...                   treatAsRegex=true  includeUnfinishedLine=${{not ${endline}}}
    ELSE
        ${result}=            Wait For Line On Uart  ${pattern}  testerId=${tester}  timeout=${timeout}
        ...                   treatAsRegex=true  includeUnfinishedLine=${{not ${endline}}}
    END
    RETURN                    ${result.Line}

Should Not Receive
    [Documentation]           Runs the emulation for ${timeout} and checks that ${pattern} did not appear on
    ...                       ${tester}. Should Not Be On Uart would leave the emulation running after it.
    [Arguments]               ${tester}  ${pattern}  ${timeout}=${ABSENCE_TIMEOUT}
    Execute Command           emulation RunFor "${timeout}"
    Should Not Be On Uart     ${pattern}  testerId=${tester}  timeout=0  treatAsRegex=true
    ...                       includeUnfinishedLine=true

Send
    [Arguments]               ${tester}  ${line}
    Write Line To Uart        ${line}  testerId=${tester}
