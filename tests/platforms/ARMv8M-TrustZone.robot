*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode/

# CMSIS-RTX
${NORTOS_S_ELF}                     ${URI}/NoRTOS_CM33_s.elf-s_125912-2f66972d08e7112cda1919429d28362ccc9edada
${NORTOS_NS_ELF}                    ${URI}/NoRTOS_CM33_ns.elf-s_116668-b55916b35e9b70237ce304fabd73ef9f035c1e0b
${RTOS_S_ELF}                       ${URI}/RTOS_CM33_s.elf-s_134680-9f39b2ee87caaf107a7adbcbcfe1e43d79d0e5a4
${RTOS_NS_ELF}                      ${URI}/RTOS_CM33_ns.elf-s_332784-b4f9860d5775c67ab3284256317f8c80e16e747c
${FAULTS_S_ELF}                     ${URI}/RTOS_Faults_CM33_s.elf-s_148128-27bb948d7e37163d790bf0c1b03fdaeeaf925028
${FAULTS_NS_ELF}                    ${URI}/RTOS_Faults_CM33_ns.elf-s_337396-5fd9fa0922a73c19c9b8b02d45417421f228197e

# Error types
${IR_UNKNOW}                        0
${IR_DIVBY0}                        1
${IR_STKOF}                         2
${IR_INVEP}                         3
${IR_WDTEXP}                        4
${IR_SECDAT}                        5

${REPL}                             SEPARATOR=\n
...                                 """
...                                 cpu: CPU.CortexM @ sysbus { cpuType: "cortex-m33"; nvic: nvic; enableTrustZone: true; }
...                                 nvic: IRQControllers.NVIC @ {
...                                 sysbus new Bus.BusPointRegistration { address: 0xE000E000; cpu: cpu };
...                                 sysbus new Bus.BusMultiRegistration { address: 0xE002E000; size: 0x1000; region: "NonSecure"; cpu: cpu }
...                                 } {-> cpu@0}
...                                 rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x20000000 }
...                                 sram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x20000000 }
...                                 ram: Memory.MappedMemory @ sysbus 0x60000000 { size: 0x20000000 }
...                                 semihosting: CPU.SemihostingHandler @ cpu
...                                 console: UART.SemihostingUart @ semihosting
...                                 """

*** Keywords ***
Create Machine
    [Arguments]                     ${ELF_S}
    ...                             ${ELF_NS}
    ...                             ${tester}=sysbus.cpu.semihosting.console

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL}
    Execute Command                 nvic FilterCcrDiv0Write False
    Execute Command                 sysbus LoadELF ${ELF_NS}
    Execute Command                 sysbus LoadELF ${ELF_S}

    Create Terminal Tester          ${tester}
    Create Log Tester               1

Add Variable Watchpoint
    [Arguments]                     ${variable_name}
    ...                             ${offset}=0
    ...                             ${width}=DoubleWord

    ${address}=                     Execute Command  sysbus GetSymbolAddress "${variable_name}"
    ${address}=                     Evaluate  ${address[:-2]} + ${offset}
    Execute Command                 sysbus AddWatchpointHook ${address} ${width} Write "self.InfoLog('Wrote '+str(value)+' to ${variable_name}${{"+"+hex(${offset}) if ${offset} > 0 else ""}}')"

Wait for Variable Write
    [Arguments]                     ${variable_name}
    ...                             ${value}
    ...                             ${pauseEmulation}=${False}

    Wait For Log Entry              Wrote ${value} to ${variable_name}  pauseEmulation=${pauseEmulation}

*** Test Cases ***
Should Pass NoRtos Test
    Create Machine                  ${NORTOS_S_ELF}  ${NORTOS_NS_ELF}

    Add Variable Watchpoint         val1
    Add Variable Watchpoint         val2

    Wait For Line On Uart           Hello from the Secure World!
    Wait For Line On Uart           Hello from the Non-secure World!
    Wait for Variable Write         val1  4
    Wait for Variable Write         val2  9

Should Pass Rtos Test
    Create Machine                  ${RTOS_S_ELF}  ${RTOS_NS_ELF}

    Add Variable Watchpoint         counterA
    Add Variable Watchpoint         counterB
    Add Variable Watchpoint         counterC

    Wait For Line On Uart           Hello from the Secure World!
    Wait For Line On Uart           Hello from the Non-secure World!

    Wait for Variable Write         counterA  3
    Wait for Variable Write         counterA  6

    Wait for Variable Write         counterB  3

    Wait for Variable Write         counterC  1
    Wait for Variable Write         counterC  2

    Wait for Variable Write         counterA  9
    Wait for Variable Write         counterA  12

    Wait for Variable Write         counterC  3
    Wait for Variable Write         counterC  4
    # ...
    # when counterC reaches value 16 it releases thread b so its counter can be incremented
    Wait for Variable Write         counterC  16

    Wait for Variable Write         counterB  7
    Wait for Variable Write         counterB  10
    # ...
    Wait for Variable Write         counterB  14

Should Pass Rtos Faults Test
    FOR  ${index}  ${expected_reason}  IN ENUMERATE  ${IR_INVEP}  ${IR_STKOF}  ${IR_DIVBY0}  ${IR_SECDAT}  ${IR_WDTEXP}
        # Currently failing test cases
        IF  ${expected_reason} in [${IR_STKOF}]
            CONTINUE
        END

        Create Machine                  ${FAULTS_S_ELF}  ${FAULTS_NS_ELF}

        ${test_case_address}=           Execute Command  sysbus GetSymbolAddress "TestCase"
        Add Variable Watchpoint         TestCase
        Add Variable Watchpoint         IncidentLog  offset=0x8  width=Byte  # IncidentLog is array of structures, but we're mainly interested in the first field of the first element as it should contain incident reason

        Wait For Line On Uart           Hello from the Secure World!
        Wait For Line On Uart           Hello from the Non-secure World!

        # Check for variable write, execute step to finish the write, update the value and continue
        Wait for Variable Write         TestCase  ${0xFFFFFFFF}  ${True}
        Execute Command                 cpu Step
        Execute Command                 sysbus WriteDoubleWord ${test_case_address} ${index}
        Execute Command                 cpu ExecutionMode Continuous

        Wait for Variable Write         IncidentLog+0x8  ${expected_reason}

        Reset Emulation
    END
