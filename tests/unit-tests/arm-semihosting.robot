*** Variables ***
# WIP: Set proper file urls
${URI}                              @https://dl.antmicro.com/projects/renode
${ARGV}                             ${URI}/semihost-argv-s_115876-ff8e8b4252f73a98e883f63c14ac61b4915eefb4
${CLOSE}                            ${URI}/semihost-close-s_115748-e7786c3fbc64b3ddf82fe172b7ebb1bd296e6006
${ERRNO}                            ${URI}/semihost-errno-s_60668-65766aec1c151e0841732ef0b8eeee5100e58d1c
${EXIT}                             ${URI}/semihost-exit-s_57900-33bc007b69c3391b622e96098b1902dbc319e2fd
${EXIT-FAILURE}                     ${URI}/semihost-exit-failure-s_49140-cfea79b96be8885bd058444a9f343174b6f4b9e9
${EXIT-EXTENDED}                    ${URI}/semihost-exit-extended-s_59876-dd881e08ed184b28a48f231062840dc5856c8d8b
${EXIT-EXTENDED-FAILURE}            ${URI}/semihost-exit-extended-failure-s_51116-f2b8d311a48ebfafa90594518e632062c8190b18
${FLEN}                             ${URI}/semihost-flen-s_118180-5008661883e9a6bc46034aac6637319d14fdf1ae
${GET-CMDLINE}                      ${URI}/semihost-get-cmdline-s_116144-e594e104222e2a4baa10aa5cea27790b94ad0e2c
${ISERROR}                          ${URI}/semihost-iserror-s_62812-0be95351d4bdaf32702f2d86954e8020be523199
${ISTTY}                            ${URI}/semihost-istty-s_118120-0f42b00819ad238d03bae0a5b8996a89556755d3
${NO-ARGV}                          ${URI}/semihost-no-argv-s_104632-668457828b8be6155e4d1a0eac6b181e742ee343
${OPEN}                             ${URI}/semihost-open-s_115964-3ae549276bf15409ffda90a29a774413fe160e64
${READ-TTY}                         ${URI}/semihost-read-tty-s_117320-254b992769723646d9a8e7cdc9cff52a1b69ef43
${READ}                             ${URI}/semihost-read-s_119964-609477adb46a5ae575fa3ad3fc8a06d815a53ad0
${READC}                            ${URI}/semihost-readc-s_113908-44bc0688a4bbfb91f968e833affa8eb12733f7bd
${REMOVE}                           ${URI}/semihost-remove-s_116256-4414d8ebb902f615d988456fc3c92a9dd51a0524
${SEEK}                             ${URI}/semihost-seek-s_121508-5a1437cf1f47317f9125a986b6f3be249d3540ef
${TMPNAM}                           ${URI}/semihost-tmpnam-s_119132-774a78f78a07b105c759282663f14134b00fe67e
${WRITE-TTY}                        ${URI}/semihost-write-tty-s_118576-054920038e048c27b319e7340e7aeefebddd1e7e
${WRITEC}                           ${URI}/semihost-writec-s_58436-f37d8cd101afce7620b15db41fe77ca60fc3e051
${WRITE0}                           ${URI}/semihost-write0-s_58800-c2283a55f28120b6dce3ad06e965a6676955b701

${REPL}                             SEPARATOR=\n
...                                 """
...                                 cpu: CPU.CortexM @ sysbus { cpuType: "cortex-m85"; nvic: nvic }
...                                 nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { -> cpu@0 }
...                                 rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x20000000 }
...                                 sram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x20000000 }
...                                 ram: Memory.MappedMemory @ sysbus 0x60000000 { size: 0x20000000 }
...                                 semihosting: CPU.SemihostingHandler @ cpu
...                                 """

${COMMON_OUTPUT}                    SEPARATOR=\n
...                                 """
...                                 console: UART.SemihostingUart @ semihosting .InputOutputError
...                                 """

${SPLIT_OUTPUT}                     SEPARATOR=\n
...                                 """
...                                 console: UART.SemihostingUart @ semihosting .InputOutput
...                                 errorConsole: UART.SemihostingUart @ semihosting .Error
...                                 """

*** Keywords ***
Create Machine
    [Arguments]                     ${ELF}
    ...                             ${separate_stderr}=${False}

    Reset Emulation
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL}

    ${semihostingDirectory}=        AllocateTemporaryDirectory  semi
    Execute Command                 cpu.semihosting WorkingDirectory @${semihostingDirectory}

    Execute Command                 sysbus LoadELF ${ELF}

    Create Log Tester               1

    IF  ${separate_stderr}
        Execute Command                 machine LoadPlatformDescriptionFromString ${SPLIT_OUTPUT}
        ${tester_id}=                   Create Terminal Tester  sysbus.cpu.semihosting.console
        ${error_tester_id}=             Create Terminal Tester  sysbus.cpu.semihosting.errorConsole
        RETURN                          ${tester_id}  ${error_tester_id}
    ELSE
        Execute Command                 machine LoadPlatformDescriptionFromString ${COMMON_OUTPUT}
        ${tester_id}=                   Create Terminal Tester  sysbus.cpu.semihosting.console
        RETURN                          ${tester_id}
    END

Check Exit Status Log
    [Arguments]                     ${expectedExitReason}=ADP_Stopped_ApplicationExit(0x20026)  # Default set to ADP_Stopped_ApplicationExit
    ...                             ${expectedExitCode}=0  # Default set to exit code 0, implying no failures. Set to None if exit code shouldn't be set

    IF  ${expectedExitCode} == ${None}
        Wait For Log Entry              cpu.semihosting: Program exited with reason ${expectedExitReason}  pauseEmulation=True
    ELSE
        Wait For Log Entry              cpu.semihosting: Program exited with reason ${expectedExitReason} and return code ${expectedExitCode}  pauseEmulation=True
    END

*** Test Cases ***
Should Pass Semihosting Tests
    FOR  ${testName}  IN
    ...  EXIT-EXTENDED
    ...  OPEN
    ...  CLOSE
    ...  ERRNO
    ...  REMOVE
    ...  READ
    ...  SEEK
    ...  FLEN
    ...  ISTTY
    ...  NO-ARGV
    ...  TMPNAM
    ...  ISERROR
        TRY
            ${elf}=                         Set Variable  ${${testName}}
            Create Machine                  ${elf}
            Check Exit Status Log
        EXCEPT  AS  ${error}
            Fail                            ${testName} test failed:\n${error}
        END
    END

Should Pass Semihosting Tests With Different Exit Status
    FOR  ${testName}  ${exitReason}  ${exitCode}  IN
    ...  EXIT  ADP_Stopped_ApplicationExit(0x20026)  ${None}
    ...  EXIT-FAILURE  ADP_Stopped_RunTimeErrorUnknown(0x20023)  ${None}
    ...  EXIT-EXTENDED-FAILURE  ADP_Stopped_ApplicationExit(0x20026)  1
        TRY
            ${elf}=                         Set Variable  ${${testName}}
            Create Machine                  ${elf}
            Check Exit Status Log           ${exitReason}  ${exitCode}
        EXCEPT  AS  ${error}
            Fail                            ${testName} test failed:\n${error}
        END
    END

Should Pass Semihosting Tests With Arguments
    FOR  ${testName}  IN
    ...  GET-CMDLINE
    ...  ARGV
        TRY
            ${elf}=                         Set Variable  ${${testName}}
            Create Machine                  ${elf}
            Execute Command                 cpu.semihosting ProgramArguments "program-name hello world"
            Check Exit Status Log
        EXCEPT  AS  ${error}
            Fail                            ${testName} test failed:\n${error}
        END
    END

Should Pass Semihosting Tests With Input
    FOR  ${testName}  IN
    ...  READ-TTY
    ...  READC
        TRY
            ${elf}=                         Set Variable  ${${testName}}
            Create Machine                  ${elf}
            Write Line To Uart              hello, world  waitForEcho=False
            Check Exit Status Log
        EXCEPT  AS  ${error}
            Fail                            ${testName} test failed:\n${error}
        END
    END

Should Pass Semihosting Tests With Output
    FOR  ${testName}  IN
    ...  WRITE-TTY
    ...  WRITE0
    ...  WRITEC
        TRY
            ${elf}=                         Set Variable  ${${testName}}
            Create Machine                  ${elf}
            Wait For Line On Uart           SUCCESS
            Check Exit Status Log
        EXCEPT  AS  ${error}
            Fail                            ${testName} test failed:\n${error}
        END
    END

Should Pass Semihosting Test With Separate Error Output
    ${stdio_tester_id}              ${error_tester_id}=  Create Machine  ${WRITE-TTY}  separate_stderr=${True}
    Wait For Line On Uart           SUCCESS  testerId=${stdio_tester_id}
    Wait For Line On Uart           ERROR  testerId=${error_tester_id}
    Check Exit Status Log

Should Pass Semihosting Test With Custom Temporary Files Directory
    Create Machine                  ${TMPNAM}
    Execute Command                 cpu.semihosting TemporaryFilesDirectory "my-temp"
    Wait For Log Entry              cpu.semihosting: SYS_TMPNAM: Created temporary files directory at: .*/semi/my-temp  pauseEmulation=True  treatAsRegex=True
    Check Exit Status Log
