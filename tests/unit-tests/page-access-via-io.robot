*** Variables ***
# Make sure mem1-3 are far apart so that they get stored on 3 different pages
${MEM1_NAME}        test_mem1
${MEM2_NAME}        test_mem2
${MEM3_NAME}        test_mem3
${MEM1_ADDR}        0x31000000
${MEM2_ADDR}        0x32000000
${MEM3_ADDR}        0x33000000

${REPL}=            SEPARATOR=
...  """                                                                ${\n}
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000                      ${\n}
...  ${SPACE*4}-> cpu@0                                                 ${\n}
...                                                                     ${\n}
...  cpu: CPU.CortexM @ sysbus                                          ${\n}
...  ${SPACE*4}cpuType: "cortex-m4"                                     ${\n}
...  ${SPACE*4}nvic: nvic                                               ${\n}
...                                                                     ${\n}
...  ram: Memory.MappedMemory @ sysbus 0x800000                         ${\n}
...  ${SPACE*4}size: 0x40000                                            ${\n}
...                                                                     ${\n}
...  ${MEM1_NAME}: Memory.MappedMemory @ sysbus ${MEM1_ADDR}            ${\n}
...  ${SPACE*4}size: 0x1000                                             ${\n}
...                                                                     ${\n}
...  ${MEM2_NAME}: Memory.MappedMemory @ sysbus ${MEM2_ADDR}            ${\n}
...  ${SPACE*4}size: 0x1000                                             ${\n}
...                                                                     ${\n}
...  ${MEM3_NAME}: Memory.MappedMemory @ sysbus ${MEM3_ADDR}            ${\n}
...  ${SPACE*4}size: 0x1000                                             ${\n}
...  """

${LOG_TIMEOUT}      1
${PC_START}         0x800000

*** Keywords ***
Write Thumb Opcode To
    [Arguments]                 ${dest}         ${opcode}
    Execute Command             sysbus WriteWord ${dest} ${opcode}

Write Address To
    [Arguments]                 ${dest}         ${address}
    Execute Command             sysbus WriteDoubleWord ${dest} ${address}

Prepare Machine
    Execute Command             mach create
    Create Log Tester           ${LOG_TIMEOUT}
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL}

    Execute Command             emulation SingleStepBlocking false
    Execute Command             sysbus.cpu PC ${PC_START}
    Execute Command             sysbus LogPeripheralAccess sysbus.${MEM1_NAME}
    Execute Command             sysbus LogPeripheralAccess sysbus.${MEM2_NAME}
    Execute Command             sysbus LogPeripheralAccess sysbus.${MEM3_NAME}

Trigger Page Access
    [Arguments]                 ${MEM}
    # Set R1 to MEM, then load the value at MEM into R0
    Execute Command             sysbus.cpu SetRegister 1 ${MEM}
    Write Thumb Opcode To       ${PC_START}     0x6808    # ldr r0, [r1, #0]

    Execute Command             sysbus.cpu PC ${PC_START}
    Execute Command             sysbus.cpu Step 1

Should Access Page Via Io
    [Arguments]                 ${MEM_NAME}         ${MEM}
    Trigger Page Access         ${MEM}
    Wait For Log Entry          ${MEM_NAME}: [cpu: ${PC_START}] ReadUInt32 from 0x0 (unknown), returned

Should Not Access Page Via Io
    [Arguments]                 ${MEM_NAME}         ${MEM}
    Trigger Page Access         ${MEM}
    Should Not Be In Log        ${MEM_NAME}: [cpu: ${PC_START}] ReadUInt32 from 0x0 (unknown), returned


*** Test Cases ***
Should Set And Clear Page Access Modes Correctly
    Prepare Machine

    Wait For Log Entry              cpu: Patching PC ${PC_START} for Thumb mode.

    Should Not Access Page Via Io   ${MEM1_NAME}    ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM2_NAME}    ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus SetPageAccessViaIo ${MEM1_ADDR}
    Should Access Page Via Io       ${MEM1_NAME}    ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM2_NAME}    ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus SetPageAccessViaIo ${MEM2_ADDR}
    Should Access Page Via Io       ${MEM1_NAME}    ${MEM1_ADDR}
    Should Access Page Via Io       ${MEM2_NAME}    ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus SetPageAccessViaIo ${MEM3_ADDR}
    Should Access Page Via Io       ${MEM1_NAME}    ${MEM1_ADDR}
    Should Access Page Via Io       ${MEM2_NAME}    ${MEM2_ADDR}
    Should Access Page Via Io       ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus ClearPageAccessViaIo ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM1_NAME}    ${MEM1_ADDR}
    Should Access Page Via Io       ${MEM2_NAME}    ${MEM2_ADDR}
    Should Access Page Via Io       ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus ClearPageAccessViaIo ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM1_NAME}    ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM2_NAME}    ${MEM2_ADDR}
    Should Access Page Via Io       ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus ClearPageAccessViaIo ${MEM3_ADDR}
    Should Not Access Page Via Io   ${MEM1_NAME}    ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM2_NAME}    ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus SetPageAccessViaIo ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM1_NAME}    ${MEM1_ADDR}
    Should Access Page Via Io       ${MEM2_NAME}    ${MEM2_ADDR}
    Should Not Access Page Via Io   ${MEM3_NAME}    ${MEM3_ADDR}

    Execute Command                 sysbus SetPageAccessViaIo ${MEM1_ADDR}
    Execute Command                 sysbus ClearPageAccessViaIo ${MEM2_ADDR}
    Execute Command                 sysbus SetPageAccessViaIo ${MEM3_ADDR}
    Should Access Page Via Io       ${MEM1_NAME}    ${MEM1_ADDR}
    Should Not Access Page Via Io   ${MEM2_NAME}    ${MEM2_ADDR}
    Should Access Page Via Io       ${MEM3_NAME}    ${MEM3_ADDR}
