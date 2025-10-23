********************************** Variables **********************************

${UART}                                sysbus.uart0
${URI}                                 @https://dl.antmicro.com/projects/renode

### CPSR

${CPSR_N_MASK}                         ${{ 0x1 << 31 }}
${CPSR_Z_MASK}                         ${{ 0x1 << 30 }}
${CPSR_C_MASK}                         ${{ 0x1 << 29 }}
${CPSR_V_MASK}                         ${{ 0x1 << 28 }}
${CPSR_Q_MASK}                         ${{ 0x1 << 27 }}
${CPSR_SSBS_MASK}                      ${{ 0x1 << 23 }}
${CPSR_PAN_MASK}                       ${{ 0x1 << 22 }}
${CPSR_IL_MASK}                        ${{ 0x1 << 20 }}
${CPSR_GE_MASK}                        ${{ 0xF << 16 }}
${CPSR_E_MASK}                         ${{ 0x1 << 9 }}
${CPSR_A_MASK}                         ${{ 0x1 << 8 }}
${CPSR_I_MASK}                         ${{ 0x1 << 7 }}
${CPSR_F_MASK}                         ${{ 0x1 << 6 }}
${CPSR_T_MASK}                         ${{ 0x1 << 5 }}
${CPSR_MODE_MASK}                      ${{ 0x1F << 0 }}

${INITIAL_CPSR_T_VALUE}                0x0
${INITIAL_CPSR_E_VALUE}                0x0

### SCTLR

${SCTLR_V_MASK}                        ${{ 1 << 13 }}
${SCTLR_M_MASK}                        ${{ 1 << 0 }}

### Privilege Level

@{AVAILABLE_PRIVILEGE_LEVELS}          User
...                                    FIQ
...                                    IRQ
...                                    Supervisor
...                                    Abort
...                                    Hypervisor
...                                    Undefined
...                                    System

@{UNAVAILABLE_PRIVILEGE_LEVELS}        Monitor
${HIGHEST_PRIVILEGE_LEVEL}             Hypervisor

### Exceptions

@{AVAILABLE_ASYNCHRONOUS_EXCEPTIONS}   IRQ  FIQ
@{AVAILABLE_SYNCHRONOUS_EXCEPTIONS}    UNDEFINED_INSTRUCTION

### Hivecs

${HIVECS_BASE_ADDRESS}                                                         0xFFFF0000
${HIVECS_DUMMY_MEMORY}                                                         SEPARATOR=
...  """                                                                       ${\n}
...  dummy_memory: Memory.MappedMemory @ sysbus ${HIVECS_BASE_ADDRESS}         ${\n}
...  \ \ \ \ size: 0x1000                                                      ${\n}
...  """


### SMP

${GIC_V2_SMP}                                                                                                           SEPARATOR=
...  """                                                                                                                ${\n}
...  using "platforms/cpus/cortex-r52_smp_4.repl"                                                                       ${\n}
...                                                                                                                     ${\n}
...  gic: @ {                                                                                                           ${\n}
...  ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0xAF000000; size: 0x010000; region: \"distributor\" };    ${\n}
...  ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0xAF100000; size: 0x200000; region: \"cpuInterface\" }    ${\n}
...  }                                                                                                                  ${\n}
...  ${SPACE*4}architectureVersion: .GICv2                                                                              ${\n}
...  """

*********************************** Keywords **********************************

### Stateless Keywords (do not depend on the current state of the simulation)

Get Updated Register Value
    [Arguments]                        ${reg_val}  ${mask}  ${new_val}
    ${result}=                         Set Variable  ${{ (${reg_val} & ~${mask}) | (${new_val} & ${mask}) }}
    RETURN                             ${result}

Get Register Field Value
    [Arguments]                        ${reg_val}  ${mask}
    ${result}=                         Set Variable  ${{ ${reg_val} & ${mask} }}
    RETURN                             ${result}

Get CPSR Field Value
    [Arguments]                        ${cpsr}  ${field}
    IF  "${field}" == "N"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_N_MASK}
    ELSE IF  "${field}" == "Z"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_Z_MASK}
    ELSE IF  "${field}" == "C"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_C_MASK}
    ELSE IF  "${field}" == "V"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_V_MASK}
    ELSE IF  "${field}" == "Q"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_Q_MASK}
    ELSE IF  "${field}" == "SSBS"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_SSBS_MASK}
    ELSE IF  "${field}" == "PAN"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_PAN_MASK}
    ELSE IF  "${field}" == "IL"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_IL_MASK}
    ELSE IF  "${field}" == "GE"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_GE_MASK}
    ELSE IF  "${field}" == "E"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_E_MASK}
    ELSE IF  "${field}" == "A"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_A_MASK}
    ELSE IF  "${field}" == "I"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_I_MASK}
    ELSE IF  "${field}" == "F"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_F_MASK}
    ELSE IF  "${field}" == "T"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_T_MASK}
    ELSE IF  "${field}" == "M" or "${field}" == "MODE"
        ${result}=  Get Register Field Value  ${cpsr}  ${CPSR_MODE_MASK}
    ELSE
        Fail  Unexpected CPSR Field Name: "${field}"
    END
    RETURN                             ${result}

Get CPSR Mode Value From Privilege Level Name
    [Arguments]                        ${pl}
    IF  "${pl}" == "User" or "${pl}" == "USR"
        ${result}=  Convert To Integer  0b10000
    ELSE IF  "${pl}" == "FIQ"
        ${result}=  Convert To Integer  0b10001
    ELSE IF  "${pl}" == "IRQ"
        ${result}=  Convert To Integer  0b10010
    ELSE IF  "${pl}" == "Supervisor" or "${pl}" == "SVC"
        ${result}=  Convert To Integer  0b10011
    ELSE IF  "${pl}" == "Monitor" or "${pl}" == "MON"
        ${result}=  Convert To Integer  0b10110
    ELSE IF  "${pl}" == "Abort" or "${pl}" == "ABT"
        ${result}=  Convert To Integer  0b10111
    ELSE IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        ${result}=  Convert To Integer  0b11010
    ELSE IF  "${pl}" == "Undefined" or "${pl}" == "UND"
        ${result}=  Convert To Integer  0b11011
    ELSE IF  "${pl}" == "System" or "${pl}" == "SYS"
        ${result}=  Convert To Integer  0b11111
    ELSE
        Fail  Unexpected Privilege Level Name: "${pl}"
    END
    RETURN                             ${result}

Get CPSR For Changed Privilege Level
    [Arguments]                        ${pl}  ${cpsr}
    ${mode_val}=                       Get CPSR Mode Value From Privilege Level Name  ${pl}
    ${new_cpsr}=                       Get Updated Register Value  ${cpsr}  ${CPSR_MODE_MASK}  ${mode_val}
    RETURN                             ${new_cpsr}

Get CPSR After Changing To Wrong Mode
    [Arguments]                        ${old_cpsr}  ${new_cpsr}
    ${mask}=                           Set Variable  ${{ ~${CPSR_MODE_MASK} }}
    ${new_cpsr}                        Set Variable  ${{ ${new_cpsr} | ${CPSR_IL_MASK} }}
    ${result}=                         Get Updated Register Value  ${old_cpsr}  ${mask}  ${new_cpsr}
    RETURN                             ${result}

Get Exception Handler Offset From Hypervisor Vector Table
    [Arguments]                                            ${exception_type}
    IF  "${exception_type}" == "UNDEFINED_INSTRUCTION"
        ${offset}=  Convert To Integer  0x4
    ELSE IF  "${exception_type}" == "HYPERVISOR_CALL"
        ${offset}=  Convert To Integer  0x8
    ELSE IF  "${exception_type}" == "PREFETCH_ABORT"
        ${offset}=  Convert To Integer  0xc
    ELSE IF  "${exception_type}" == "DATA_ABORT"
        ${offset}=  Convert To Integer  0x10
    ELSE IF  "${exception_type}" == "HYP_TRAP"
        ${offset}=  Convert To Integer  0x14
    ELSE IF  "${exception_type}" == "IRQ"
        ${offset}=  Convert To Integer  0x18
    ELSE IF  "${exception_type}" == "FIQ"
        ${offset}=  Convert To Integer  0x1c
    ELSE
        Fail  Unexpected Exception Type Name: "${exception_type}"
    END
    RETURN                                                 ${offset}

Get Exception Handler Offset From Non-Secure Vector Table
    [Arguments]                                            ${exception_type}
    IF  "${exception_type}" == "UNDEFINED_INSTRUCTION"
        ${offset}=  Convert To Integer  0x4
    ELSE IF  "${exception_type}" == "SUPERVISOR_CALL"
        ${offset}=  Convert To Integer  0x8
    ELSE IF  "${exception_type}" == "PREFETCH_ABORT"
        ${offset}=  Convert To Integer  0xc
    ELSE IF  "${exception_type}" == "DATA_ABORT"
        ${offset}=  Convert To Integer  0x10
    ELSE IF  "${exception_type}" == "IRQ"
        ${offset}=  Convert To Integer  0x18
    ELSE IF  "${exception_type}" == "FIQ"
        ${offset}=  Convert To Integer  0x1c
    ELSE
        Fail  Unexpected Exception Type Name: "${exception_type}"
    END
    RETURN                                                 ${offset}

Get Exception Handler Offset
    [Arguments]                                            ${pl}  ${excp_type}
    IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        ${offset}=                                         Get Exception Handler Offset From Hypervisor Vector Table  ${excp_type}
    ELSE
        ${offset}=                                         Get Exception Handler Offset From Non-Secure Vector Table  ${excp_type}
    END
    RETURN                                                 ${offset}

Convert Integer To Hex String
    [Arguments]                        ${value}
    ${result}=                         Convert To Hex  ${value}  prefix=0x
    RETURN                             ${result}

Contains Substring
    [Arguments]                        ${str}  ${substr}
    ${result}=                         Run Keyword And Return Status  Should Contain  ${str}  ${substr}
    RETURN                             ${result}

### Stateful Keywords (they depend on the current state of the simulation)

Get Current CPSR Value
    ${cpsr}=                           Execute Command  sysbus.cpu CPSR
    ${cpsr}=                           Convert To Integer  ${cpsr}
    RETURN                             ${cpsr}

Set Current CPSR Value
    [Arguments]                        ${value}
    ${value_str}=                      Convert Integer To Hex String  ${value}
    Execute Command                    sysbus.cpu CPSR ${value_str}

Get Current Privilege Level Value
    ${cpsr}=                           Get Current CPSR Value
    ${mode}=                           Get Register Field Value  ${cpsr}  ${CPSR_MODE_MASK}
    RETURN                             ${mode}

Set Current Privilege Level Value
    [Arguments]                        ${pl}
    ${current_cpsr}=                   Get Current CPSR Value
    ${new_cpsr}=                       Get CPSR For Changed Privilege Level  ${pl}  ${current_cpsr}
    ${new_cpsr}=                       Convert Integer To Hex String  ${new_cpsr}
    Execute Command                    sysbus.cpu CPSR ${new_cpsr}

Get Current PC Value
    ${pc}=                             Execute Command  sysbus.cpu PC
    ${pc}=                             Convert To Integer  ${pc}
    RETURN                             ${pc}

Set Current PC Value
    [Arguments]                        ${value}
    ${value_str}=                      Convert Integer To Hex String  ${value}
    Execute Command                    sysbus.cpu PC ${value_str}

Get Current CPSR Field Value
    [Arguments]                        ${field}
    ${cpsr}=                           Get Current CPSR Value
    ${result}=                         Get CPSR Field Value  ${cpsr}  ${field}
    RETURN                             ${result}

Get Current System Register Value
    [Arguments]                                            ${reg_name}
    ${reg_value}=                                          Execute Command  sysbus.cpu GetSystemRegisterValue \"${reg_name}\"
    ${result}=                                             Convert To Integer  ${reg_value}
    Check For Register Errors In Last Log                  ${reg_name}
    RETURN                                                 ${result}

Set Current System Register Value
    [Arguments]                                            ${reg_name}  ${value}
    ${value_str}=                                          Convert Integer To Hex String  ${value}
    Execute Command                                        sysbus.cpu SetSystemRegisterValue \"${reg_name}\" ${value_str}
    Check For Register Errors In Last Log                  ${reg_name}

Set Asynchronous Exception
    [Arguments]                                            ${exception_type}
    IF  "${exception_type}" == "IRQ"
        Execute Command                                    sysbus.cpu OnGPIO 0 True
    ELSE IF  "${exception_type}" == "FIQ"
        Execute Command                                    sysbus.cpu OnGPIO 1 True
    ELSE
        Fail  Unexpected Exception Type Name: "${exception_type}"
    END

Set Synchronous Exception
    [Arguments]                                            ${exception_type}
    IF  "${exception_type}" == "UNDEFINED_INSTRUCTION"
        ${pc}=                                             Get Current PC Value
        Write Opcode To Address                            ${pc}  0xDEADBEEF
        Execute Command                                    sysbus.cpu Step
    ELSE IF  "${exception_type}" == "HYPERVISOR_CALL"
        Fail  Forcing "${exception_type}" is not supported
    ELSE IF  "${exception_type}" == "SUPERVISOR_CALL"
        Fail  Forcing "${exception_type}" is not supported
    ELSE IF  "${exception_type}" == "PREFETCH_ABORT"
        Fail  Forcing "${exception_type}" is not supported
    ELSE IF  "${exception_type}" == "DATA_ABORT"
        Fail  Forcing "${exception_type}" is not supported
    ELSE
        Fail  Unexpected Exception Type Name: "${exception_type}"
    END

Set Exception Vector Base Address
    [Arguments]                                            ${pl}  ${base_address}
    IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        Set Current System Register Value                  HVBAR  ${base_address}  # exceptions taken to hypervisor mode
    ELSE
        Set Current System Register Value                  VBAR  ${base_address}  # exceptions taken to non-secure mode
    END

Reset CPU
    Execute Command                    sysbus.cpu Reset

Enable Hivecs
    ${sctlr}=                          Get Current System Register Value  SCTLR
    ${sctlr}=                          Get Updated Register Value  ${sctlr}  ${SCTLR_V_MASK}  ${SCTLR_V_MASK}
    Set Current System Register Value  SCTLR  ${sctlr}

Enable EL2 MPU
    ${sctlr}=                          Get Current System Register Value  HSCTLR
    ${sctlr}=                          Get Updated Register Value  ${sctlr}  ${SCTLR_M_MASK}  ${SCTLR_M_MASK}
    Set Current System Register Value  HSCTLR  ${sctlr}

Enable EL1 MPU
    ${sctlr}=                          Get Current System Register Value  SCTLR
    ${sctlr}=                          Get Updated Register Value  ${sctlr}  ${SCTLR_M_MASK}  ${SCTLR_M_MASK}
    Set Current System Register Value  SCTLR  ${sctlr}

Unmask Exception
    [Arguments]                        ${excp_name}
    ${mask}                            Set Variable  0x0
    IF  "${excp_name}" == "A" or "${excp_name}" == "SERROR"
        ${mask}=                       Set Variable  ${{ ${mask} | ${CPSR_A_MASK} }}
    END
    IF  "${excp_name}" == "I" or "${excp_name}" == "IRQ"
        ${mask}=                       Set Variable  ${{ ${mask} | ${CPSR_I_MASK} }}
    END
    IF  "${excp_name}" == "F" or "${excp_name}" == "FIQ"
        ${mask}=                       Set Variable  ${{ ${mask} | ${CPSR_F_MASK} }}
    END
    ${cpsr}=                           Get Current CPSR Value
    ${new_cpsr}=                       Get Updated Register Value  ${cpsr}  ${mask}  0
    Set Current CPSR Value             ${new_cpsr}

Check For Register Errors In Last Log
    [Arguments]                        ${reg_name}
    ${log}=                            Execute Command  lastLog 1
    ${contains_reg_error}              Contains Substring  ${log}  system register failure
    ${contains_reg_name}               Contains Substring  ${log}  ${reg_name}
    IF  ${contains_reg_error} and ${contains_reg_name}
        Fail                           "${reg_name}" register does not exist!
    END

Write Opcode To Address
    [Arguments]                        ${address}  ${opcode}
    Execute Command                    sysbus WriteDoubleWord ${address} ${opcode}

Current Privilege Level Should Be
    [Arguments]                        ${pl}
    ${current_pl}=                     Get Current Privilege Level Value
    ${expected_pl}=                    Get CPSR Mode Value From Privilege Level Name  ${pl}
    Should Be Equal As Integers        ${current_pl}  ${expected_pl}

Current PC Should Be
    [Arguments]                        ${expected_pc}
    ${current_pc}=                     Get Current PC Value
    Should Be Equal As Integers        ${current_pc}  ${expected_pc}

Current CPSR Should Be
    [Arguments]                        ${expected_cpsr}
    ${cpsr}=                           Get Current CPSR Value
    Should Be Equal As Integers        ${cpsr}  ${expected_cpsr}

Current CPSR Field Should Be
    [Arguments]                        ${field}  ${expected_value}
    ${val}=                            Get Current CPSR Field Value  ${field}
    Should Be Equal As Integers        ${val}  ${expected_value}

Current CPSR Flag Should Be Set
    [Arguments]                        ${flag}
    ${val}=                            Get Current CPSR Field Value  ${flag}
    Should Be Equal As Integers        ${val}  1

Current CPSR Flag Should Be Unset
    [Arguments]                        ${flag}
    ${val}=                            Get Current CPSR Field Value  ${flag}
    Should Be Equal As Integers        ${val}  0

Current System Register Value Should Be
    [Arguments]                        ${reg_name}  ${expected_value}
    ${reg_value}=                      Get Current System Register Value  ${reg_name}
    Should Be Equal As Integers        ${reg_value}  ${expected_value}

### Auxiliary Keywords (not general keywords used to simplify test cases)

Initialize Emulation
    [Arguments]                                            ${exec_mode}=Continuous  ${pl}=default  ${pc}=default  ${elf}=default
    ...                                                    ${binary}=default  ${create_uart_tester}=False  ${map_memory}=False

    # Tests assume Renode prints HEX numbers.
    Execute Command                                        numbersMode Hexadecimal

    Execute Command                                        mach create
    Execute Command                                        machine LoadPlatformDescription @platforms/cpus/cortex-r52.repl
    Execute Command                                        sysbus.cpu ExecutionMode ${exec_mode}

    # Map all addresses as read/write and executable for EL2, EL1, and EL0
    IF  ${map_memory}
        # Set Attr0 to Normal, Outer-Read and -Write
        Set Current System Register Value                  MAIR0  0x70
        # Set base address to 0, Outer Shareable, and Read-Write at EL1 and EL0, and disable execute never
        Set Current System Register Value                  PRBAR  0x12
        # Set limit address to 0xFFFFFFFF, select Attr0, and enable the region
        Set Current System Register Value                  PRLAR  0xFFFFFFC1
        Enable EL1 MPU

        # Set Attr0 to Normal, Outer-Read and -Write
        Set Current System Register Value                  HMAIR0  0x70
        # Set base address to 0, Outer Shareable, and Read-Write at EL2, EL1, and EL0, and disable execute never
        Set Current System Register Value                  HPRBAR  0x12
        # Set limit address to 0xFFFFFFFF, select Attr0, and enable the region
        Set Current System Register Value                  HPRLAR  0xFFFFFFC1
        Enable EL2 MPU
    END

    IF  "${elf}" != "default"
        Execute Command                                    sysbus LoadELF ${elf}
    END
    IF  "${binary}" != "default"
        Execute Command                                    sysbus LoadBinary ${binary}
    END

    IF  "${pl}" != "default"
        Set Current Privilege Level Value                  ${pl}
        Current Privilege Level Should Be                  ${pl}
    END
    IF  "${pc}" != "default"
        Set Current PC Value                               ${pc}
        Current PC Should Be                               ${pc}
    END

    IF  ${create_uart_tester}
        Create Terminal Tester                             ${UART}  defaultPauseEmulation=True
        Execute Command                                    showAnalyzer ${UART}
    END

Check If CPSR Contains Reset Values
    Current CPSR Field Should Be                           A  ${CPSR_A_MASK}
    Current CPSR Field Should Be                           I  ${CPSR_I_MASK}
    Current CPSR Field Should Be                           F  ${CPSR_F_MASK}
    Current CPSR Field Should Be                           IL  0x0
    Current CPSR Field Should Be                           T  ${INITIAL_CPSR_T_VALUE}
    Current CPSR Field Should Be                           E  ${INITIAL_CPSR_E_VALUE}

Check If Current PC Equal To RVBAR
    ${rvbar_value}=                                        Get Current System Register Value  RVBAR
    Current PC Should Be                                   ${rvbar_value}

Add Dummy Memory At Hivecs Base Address
    Execute Command                                        machine LoadPlatformDescriptionFromString ${HIVECS_DUMMY_MEMORY}

Check Protection Region Address Register Access Through Selector Register
    [Arguments]                                            ${direct_addr_reg}  ${selected_addr_reg}  ${selector_reg}  ${region_num}  ${reserved_mask}
    ${WRITE_VALUE}                                         Set Variable  0xFFFFFFFF
    ${EXPECTED_REG_VALUE}=                                 Evaluate  0xFFFFFFFF ^ ${reserved_mask}
    Set Current System Register Value                      ${selector_reg}  ${region_num}
    Set Current System Register Value                      ${selected_addr_reg}  ${WRITE_VALUE}
    ${reg_value}=                                          Get Current System Register Value  ${direct_addr_reg}
    Should Be Equal As Integers                            ${reg_value}  ${EXPECTED_REG_VALUE}

Check Protection Region Address Register Access Through Direct Register
    [Arguments]                                            ${direct_addr_reg}  ${selected_addr_reg}  ${region_selector_reg}  ${region_num}  ${reserved_mask}
    ${WRITE_VALUE}                                         Set Variable  0xFFFFFFFF
    ${EXPECTED_REG_VALUE}=                                 Evaluate  0xFFFFFFFF ^ ${reserved_mask}
    Set Current System Register Value                      ${direct_addr_reg}  ${WRITE_VALUE}
    Set Current System Register Value                      ${region_selector_reg}  ${region_num}
    ${reg_value}=                                          Get Current System Register Value  ${selected_addr_reg}
    Should Be Equal As Integers                            ${reg_value}  ${EXPECTED_REG_VALUE}

Check Debug Exceptions Template
    [Arguments]                                            ${instruction}  ${handler_offset}  ${DBGDSCRext}  ${step}  ${return_address}
    ${HANDLER_ADDRESS}=                                    Set Variable  0x8010

    IF  "${instruction}" == "BKPT"
        ${opcode}=  Set Variable  0xE1200070
    ELSE IF  "${instruction}" == "SVC"
        ${opcode}=  Set Variable  0xEF000000
    ELSE IF  "${instruction}" == "HVC"
        ${opcode}=  Set Variable  0xE1400070
    ELSE
        Fail  Unexpected instruction: "${instruction}"
    END

    Initialize Emulation                                   pc=0x8000  exec_mode=SingleStep
    Write Opcode To Address                                0x8000  0xE3080010  # mov r0, #0x8010  @ HANDLER_ADDRESS
    Write Opcode To Address                                0x8004  0xEE8C0F10  # mcr p15, 4, r0, c12, c0, 0  @ set HVBAR
    Write Opcode To Address                                0x8008  ${opcode}  # instruction #0
    Write Opcode To Address                                0x800C  0xEAFFFFFD  # b 0x8008
    Write Opcode To Address                                0x8010  0xE1A00000  # nop
    Write Opcode To Address                                0x8014  0xE1A00000  # nop
    Write Opcode To Address                                0x8018  0xE1A00000  # nop
    Write Opcode To Address                                0x801C  0xE160006E  # eret
    Start Emulation

    Execute Command                                        sysbus.cpu Step 3
    Current PC Should Be                                   ${{ ${HANDLER_ADDRESS} + ${handler_offset} }}
    Current System Register Value Should Be                DBGDSCRext  ${DBGDSCRext}
    Current CPSR Field Should Be                           A  ${CPSR_A_MASK}
    Current CPSR Field Should Be                           I  ${CPSR_I_MASK}
    Current CPSR Field Should Be                           F  ${CPSR_F_MASK}
    Execute Command                                        sysbus.cpu Step ${step}
    Current PC Should Be                                   ${return_address}

    [Teardown]                                             Reset Emulation

Check Synchronous Exceptions Handling Template
    [Arguments]                                            ${pl}  ${exception_type}
    ${EXCEPTION_HANDLER_BASE_ADDRESS}=                     Set Variable  0x8000
    ${EXCEPTION_HANDLER_OFFSET}=                           Get Exception Handler Offset  ${pl}  ${exception_type}
    ${EXPECTED_PC}=                                        Set Variable  ${{ ${EXCEPTION_HANDLER_BASE_ADDRESS} + ${EXCEPTION_HANDLER_OFFSET} }}

    Initialize Emulation                                   pl=${pl}  exec_mode=SingleStep  map_memory=True
    Unmask Exception                                       ${exception_type}
    Start Emulation

    Set Exception Vector Base Address                      ${pl}  ${EXCEPTION_HANDLER_BASE_ADDRESS}
    Set Synchronous Exception                              ${exception_type}
    Current PC Should Be                                   ${EXPECTED_PC}

    [Teardown]                                             Reset Emulation

Check Asynchronous Exceptions Handling Template
    [Arguments]                                            ${pl}  ${exception_type}
    ${EXCEPTION_HANDLER_BASE_ADDRESS}=                     Set Variable  0x8000
    ${EXCEPTION_HANDLER_OFFSET}=                           Get Exception Handler Offset  ${pl}  ${exception_type}
    ${EXPECTED_PC}=                                        Set Variable  ${{ ${EXCEPTION_HANDLER_BASE_ADDRESS} + ${EXCEPTION_HANDLER_OFFSET} }}

    Initialize Emulation                                   pl=${pl}  exec_mode=SingleStep
    Unmask Exception                                       ${exception_type}
    Start Emulation

    Set Exception Vector Base Address                      ${pl}  ${EXCEPTION_HANDLER_BASE_ADDRESS}
    Set Asynchronous Exception                             ${exception_type}
    Execute Command                                        sysbus.cpu Step

    # FIXME: An artificial 0x4 offset was added because Renode executes
    # two instructions after entering exception handler with Step command
    Current PC Should Be                                   ${{ ${EXPECTED_PC} + 0x4 }}

    [Teardown]                                             Reset Emulation

### Template Keywords (keywords used in test templates)

Check Changing Privilege Level From Monitor Template
    [Arguments]                                            ${pl}

    Initialize Emulation                                   pl=${pl}

Check Value Of System Registers After Initialization Template
    [Arguments]                                            ${reg_name}  ${value}

    Initialize Emulation
    Current System Register Value Should Be                ${reg_name}  ${value}

    [Teardown]                                             Reset Emulation

Check Value Of System Registers After Reset Template
    [Arguments]                                            ${reg_name}  ${value}  ${access}

    Initialize Emulation
    IF  "${access}" == "RW"
        Set Current System Register Value                  ${reg_name}  0xDEADBEEF
    END

    Reset CPU
    Current System Register Value Should Be                ${reg_name}  ${value}

    [Teardown]                                             Reset Emulation

Check Access To SPSR_hyp Register Template
    [Arguments]                                            ${pl}

    Initialize Emulation                                   pl=${pl}  pc=0x8000  exec_mode=SingleStep  map_memory=True
    Write Opcode To Address                                0x8000  0xe16ef300  # msr SPSR_hyp, r0
    Start Emulation

    Execute Command                                        sysbus.cpu Step
    IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        # SPSR_hyp accesses from Hypervisor mode are UNPREDICTABLE. However, a common Cortex-R52 initialization procedure,
        # that works correctly on hardware and in FVP, sets it so Renode also allows for such accesses.
        Current Privilege Level Should Be                  Hypervisor
        Current PC Should Be                                   0x8004
    ELSE
        # SPSR_hyp access from other Privilege Levels causes
        # Undefined Instruction Exception handled at Undefined Privilege Level
        Current Privilege Level Should Be                  Undefined
        Current PC Should Be                                   0x4
    END

    [Teardown]                                             Reset Emulation

Check Access To ELR_hyp Template
    [Arguments]                                            ${pl}  ${expected_access_allowed}

    Initialize Emulation                                   pl=${pl}  pc=0x8000  exec_mode=SingleStep  map_memory=True
    Write Opcode To Address                                0x8000  0xe30c0afe  # movw    r0, #51966      ; 0xcafe
    Write Opcode To Address                                0x8004  0xe12ef300  # msr     ELR_hyp, r0
    Write Opcode To Address                                0x8008  0xe10e1300  # mrs     r1, ELR_hyp
    Write Opcode To Address                                0x800C  0xe1500001  # cmp     r0, r1
    Start Emulation

    IF  ${expected_access_allowed} == True
        Execute Command                                    sysbus.cpu Step 3
        Current CPSR Flag Should Be Unset                  C
        Current Privilege Level Should Be                  ${pl}
    ELSE
        Execute Command                                    sysbus.cpu Step 2
        Current PC Should Be                               0x4
        Current Privilege Level Should Be                  Undefined
    END

    [Teardown]                                             Reset Emulation

Check CPSR_c Instruction Changing Privilege Level To User Template
    [Arguments]                                            ${pl}  ${expected_access_allowed}
    ${TARGET_CPSR}=                                        Set Variable  0x40000110
    ${EXPECTED_PC}=                                        Set Variable  0x8004

    Initialize Emulation                                   pl=${pl}  pc=0x8000  exec_mode=SingleStep  map_memory=True
    Write Opcode To Address                                0x8000  0xe321f010  # msr CPSR_c, #16
    Start Emulation

    ${unmodified_cpsr}=                                    Get Current CPSR Value
    Execute Command                                        sysbus.cpu Step
    IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        ${expected_cpsr}=                                  Get CPSR After Changing To Wrong Mode  ${unmodified_cpsr}  ${TARGET_CPSR}
    ELSE
        IF  ${expected_access_allowed} == True
           ${expected_cpsr}=                               Set Variable  ${TARGET_CPSR}
        ELSE
           ${expected_cpsr}=                               Set Variable  ${unmodified_cpsr}
        END
    END
    Current PC Should Be                                   ${EXPECTED_PC}
    Current CPSR Should Be                                 ${expected_cpsr}

    [Teardown]                                             Reset Emulation

Check VBAR Register Usage By IRQ Template
    [Arguments]                                            ${pl}
    ${EXCEPTION_VECTOR_ADDRESS}=                           Set Variable  0x8000
    ${IRQ_HANDLER_OFFSET}=                                 Set Variable  0x18
    ${EXPECTED_PC}=                                        Set Variable  ${{ ${EXCEPTION_VECTOR_ADDRESS} + ${IRQ_HANDLER_OFFSET} }}

    Initialize Emulation                                   pl=${pl}  exec_mode=SingleStep
    Unmask Exception                                       IRQ
    Start Emulation

    Set Exception Vector Base Address                      ${pl}  ${EXCEPTION_VECTOR_ADDRESS}
    Set Asynchronous Exception                             IRQ
    Execute Command                                        sysbus.cpu Step

    # FIXME: An artificial 0x4 offset was added because Renode executes two instructions after entering IRQ handler with Step command
    Current PC Should Be                                   ${{ ${expected_pc} + 0x4 }}

    [Teardown]                                             Reset Emulation

Check High Exception Vectors Usage By IRQ Template
    [Arguments]                                            ${pl}
    ${IRQ_HANDLER_BASE}=                                   Set Variable  0xFFFF0000
    ${IRQ_HANDLER_OFFSET}=                                 Set Variable  0x18
    ${EXPECTED_PC}=                                        Set Variable  ${{ ${IRQ_HANDLER_BASE} + ${IRQ_HANDLER_OFFSET} }}

    Initialize Emulation                                   pl=${pl}  exec_mode=SingleStep  map_memory=True
    Add Dummy Memory At Hivecs Base Address                # Prevent CPU abort error when trying to execute code from hivecs addresses
    Unmask Exception                                       IRQ
    Enable Hivecs
    Start Emulation

    Set Asynchronous Exception                             IRQ
    Execute Command                                        sysbus.cpu Step

    # FIXME: An artificial 0x4 offset was added because Renode executes
    # two instructions after entering exception handler with Step command
    Current PC Should Be                                   ${{ ${EXPECTED_PC} + 0x4 }}

    [Teardown]                                             Reset Emulation

Check Protection Region Address Register Access Template
    [Arguments]                                            ${pl}  ${reg_type}  ${region_num}

    Initialize Emulation                                   pl=${pl}  exec_mode=SingleStep
    Start Emulation

    IF  "${reg_type}" == "Base" or "${reg_type}" == "BAR"
        ${direct_addr_reg}=                                Set Variable  PRBAR
        ${selector_reg}=                                   Set Variable  PRSELR
        ${reserved_mask}=                                  Set Variable  0x20
    ELSE IF  "${reg_type}" == "Limit" or "${reg_type}" == "LAR"
        ${direct_addr_reg}=                                Set Variable  PRLAR
        ${selector_reg}=                                   Set Variable  PRSELR
        ${reserved_mask}=                                  Set Variable  0x30
    ELSE
        Fail  "Incorrect Protection Region Type"
    END
    ${selected_addr_reg}=                                  Catenate  SEPARATOR=   ${direct_addr_reg}  ${region_num}
    IF  "${pl}" == "Hypervisor" or "${pl}" == "HYP"
        ${direct_addr_reg}=                                Catenate  SEPARATOR=   H  ${direct_addr_reg}
        ${selected_addr_reg}=                              Catenate  SEPARATOR=   H  ${selected_addr_reg}
        ${selector_reg}=                                   Catenate  SEPARATOR=   H  ${selector_reg}
    END
    Check Protection Region Address Register Access Through Selector Register  ${direct_addr_reg}  ${selected_addr_reg}  ${selector_reg}  ${region_num}  ${reserved_mask}
    Check Protection Region Address Register Access Through Direct Register  ${direct_addr_reg}  ${selected_addr_reg}  ${selector_reg}  ${region_num}  ${reserved_mask}

    [Teardown]                                             Reset Emulation

********************************** Test Cases *********************************

### Prerequisites

Should Get Correct EL and SS on CPU Creation
    # This platform uses `Cortex-R52` CPU - ARMv8R in AArch32 configuration
    # We only check if EL and SS are reflected correctly on C# side, for their usage in peripherals
    Initialize Emulation

    ${ss}=                             Execute Command  sysbus.cpu SecurityState
    ${el}=                             Execute Command  sysbus.cpu ExceptionLevel

    Should Be Equal As Strings         ${ss.split()[0].strip()}  NonSecure
    Should Be Equal As Strings         ${el.split()[0].strip()}  EL2_HypervisorMode

Check Changing Privilege Level From Monitor
    [Template]                         Check Changing Privilege Level From Monitor Template
    [Tags]                             Prerequisite

    FOR  ${pl}  IN  @{AVAILABLE_PRIVILEGE_LEVELS}
        ${pl}
    END

Check Writing To System Registers From Monitor
    [Tags]                             Prerequisite

    Initialize Emulation
    Set Current System Register Value                      VBAR  0xCAFE0000
    Current System Register Value Should Be                VBAR  0xCAFE0000

### CPU Initialization

Check Privilege Level After Initialization
    [Tags]                             Initialization

    Initialize Emulation
    Current Privilege Level Should Be  ${HIGHEST_PRIVILEGE_LEVEL}

Check CPSR Value After Initialization
    [Tags]                             Initialization

    Initialize Emulation
    Check If CPSR Contains Reset Values

Check PC Value After Initialization
    [Tags]                             Initialization

    Initialize Emulation
    Check If Current PC Equal To RVBAR

### CPU Reset

Check PC Value After Reset
    [Tags]                             Reset

    Initialize Emulation
    Reset CPU
    Check If Current PC Equal To RVBAR

### Hypervisor

Check Access To SPSR_hyp Register
    [Template]                         Check Access To SPSR_hyp Register Template
    [Tags]                             Hypervisor

    FOR  ${pl}  IN  @{AVAILABLE_PRIVILEGE_LEVELS}
        ${pl}
    END

Check Access To ELR_hyp Register
    [Template]                         Check Access To ELR_hyp Template
    [Tags]                             Hypervisor

    User                               False
    FIQ                                False
    IRQ                                False
    Supervisor                         False
    Abort                              False
    Hypervisor                         True
    Undefined                          False
    System                             False

### Basic Operation

Check CPSR_c Instruction Changing Privilege Level To User
    [Template]                         Check CPSR_c Instruction Changing Privilege Level To User Template
    [Tags]                             Basic Operation

    User                               False
    FIQ                                True
    IRQ                                True
    Supervisor                         True
    Hypervisor                         True
    Abort                              True
    Undefined                          True
    System                             True

### Exceptions

Check VBAR Register Usage By IRQ
    [Template]                         Check VBAR Register Usage By IRQ Template
    [Tags]                             Exceptions

    User
    FIQ
    IRQ
    Supervisor
    Hypervisor
    Abort
    Undefined
    System

Check High Exception Vectors Usage By IRQ
    [Template]                         Check High Exception Vectors Usage By IRQ Template
    [Tags]                             Exceptions

    User
    FIQ
    IRQ
    Supervisor
    Hypervisor
    Abort
    Undefined
    System

Check Debug Exceptions
    [Template]                         Check Debug Exceptions Template
    [Tags]                             Exceptions

    BKPT    0xC  0xC  1  0x8008
    SVC     0x8  0x0  2  0x800c
    HVC     0x8  0x0  2  0x800c

Check Asynchronous Exceptions Handling
    [Template]                         Check Asynchronous Exceptions Handling Template
    [Tags]                             Exceptions

    FOR  ${pl}  IN  @{AVAILABLE_PRIVILEGE_LEVELS}
        FOR  ${exception_type}  IN  @{AVAILABLE_ASYNCHRONOUS_EXCEPTIONS}
            ${pl}                      ${exception_type}
        END
    END

Check Synchronous Exceptions Handling
    [Template]                         Check Synchronous Exceptions Handling Template
    [Tags]                             Exceptions

    FOR  ${pl}  IN  @{AVAILABLE_PRIVILEGE_LEVELS}
        FOR  ${exception_type}  IN  @{AVAILABLE_SYNCHRONOUS_EXCEPTIONS}
            ${pl}                      ${exception_type}
        END
    END

### Address Translation Registers

Check Protection Region Address Register Access
    [Template]                         Check Protection Region Address Register Access Template
    [Tags]                             MPU

    FOR  ${region_num}  IN  0  7  15
        User        Base   ${region_num}
        User        Limit  ${region_num}
        Hypervisor  Base   ${region_num}
        Hypervisor  Limit  ${region_num}
    END

### Demos

Run Zephyr Hello World Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/aemv8r_aarch32--zephyr-hello_world.elf-s_390996-d824c18d2044d741b7761f7ab27d3b49fae9a9e4
    ...                                create_uart_tester=True

    Wait For Line On Uart              *** Booting Zephyr OS build ${SPACE}***
    Wait For Line On Uart              Hello World! fvp_baser_aemv8r_aarch32

Run Zephyr Synchronization Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-synchronization.elf-s_402972-0cd785e0ec32a0c9106dec5369ad36e4b4fb386f
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              thread_a: Hello World from cpu 0 on fvp_baser_aemv8r_aarch32!
    Wait For Line On Uart              thread_b: Hello World from cpu 0 on fvp_baser_aemv8r_aarch32!
    Wait For Line On Uart              thread_a: Hello World from cpu 0 on fvp_baser_aemv8r_aarch32!
    Wait For Line On Uart              thread_b: Hello World from cpu 0 on fvp_baser_aemv8r_aarch32!

Run Zephyr Philosophers Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-philosophers.elf-s_500280-b9bbb31c64dec3f3273535be657b8e4d7ca182f9
    ...                                create_uart_tester=True

    Wait For Line On Uart              Philosopher 0.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 0.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 0.*EATING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 1.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 1.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 1.*EATING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 2.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 2.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 2.*EATING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 3.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 3.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 3.*EATING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 4.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 4.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 4.*EATING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 5.*THINKING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 5.*HOLDING  treatAsRegex=true
    Wait For Line On Uart              Philosopher 5.*EATING  treatAsRegex=true

Run Zephyr User Space Hello World Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-userspace_hello_world_user.elf-s_1039836-cbc30725dd16eeb46c01b921f0c96e6a927c3669
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              Hello World from UserSpace! (fvp_baser_aemv8r_aarch32)

Run Zephyr User Space Prod Consumer Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-userspace_prod_consumer.elf-s_1291928-637dbadb671ac5811ed6390b6be09447e586bf82
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Provides                           zephyr-userspace_prod_consumer-after-booting
    Wait For Line On Uart              I: SUCCESS

Test Resuming Zephyr User Space Prod Consumer After Deserialization
    Requires                           zephyr-userspace_prod_consumer-after-booting
    Execute Command                    showAnalyzer ${UART}
    Wait For Line On Uart              I: SUCCESS

Run Zephyr User Space Shared Mem Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-userspace_shared_mem.elf-s_1096936-6da5eb0f22c62b0a23f66f68a4ba51b9ece6deff
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              PT Sending Message 1
    Wait For Line On Uart              ENC Thread Received Data
    Wait For Line On Uart              ENC PT MSG: PT: message to encrypt
    Wait For Line On Uart              CT Thread Received Message
    Wait For Line On Uart              CT MSG: ofttbhfspgmeqzos
    Wait For Line On Uart              PT Sending Message 1'
    Wait For Line On Uart              ENC Thread Received Data
    Wait For Line On Uart              ENC PT MSG: ofttbhfspgmeqzos
    Wait For Line On Uart              CT Thread Received Message
    Wait For Line On Uart              CT MSG: messagetoencrypt

Run Zephyr Basic Sys Heap Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-basic_sys_heap.elf-s_433924-f490ec4c563a8f553702b7203956bf961242d91b
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              allocated 0, free 196, max allocated 0, heap size 256
    Wait For Line On Uart              allocated 156, free 36, max allocated 156, heap size 256
    Wait For Line On Uart              allocated 100, free 92, max allocated 156, heap size 256
    Wait For Line On Uart              allocated 0, free 196, max allocated 156, heap size 256

Run Zephyr Compression LZ4 Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-compression_lz4.elf-s_840288-1558c5d70a6fa74ffebf6fe8a31398d29af0d087
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              Successfully decompressed some data
    Wait For Line On Uart              Validation done. The string we ended up with is:

Run Zephyr Cpp Synchronization Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-cpp_cpp_synchronization.elf-s_488868-3ac689f04acc81aaf0e10b7979f12a8d66ba73d7
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              Create semaphore 0x4e04
    Wait For Line On Uart              Create semaphore 0x4df0
    Wait For Line On Uart              main: Hello World!
    Wait For Line On Uart              coop_thread_entry: Hello World!
    Wait For Line On Uart              main: Hello World!
    Wait For Line On Uart              coop_thread_entry: Hello World!

Run Zephyr Kernel Condition Variables Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-kernel_condition_variables_condvar.elf-s_478952-6ef5d598b47ef8dd8a624ffb85e4cb60fc2c6736
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              Main(): Waited and joined with 3 threads. Final value of count = 145. Done.

Run Zephyr Kernel Condition Variables Simple Sample
    [Tags]                             Demos

    Initialize Emulation               elf=${URI}/fvp_baser_aemv8r_aarch32--zephyr-kernel_condition_variables_simple.elf-s_476108-e8c6ccae3076acc95f23fc3c726b4bcb8e20fff1
    ...                                create_uart_tester=True

    Wait For Line On Uart              Booting Zephyr OS build
    Wait For Line On Uart              [thread main] done == 20 so everyone is done

Test Reading From Overlapping MPU Regions
    [Tags]                             Exceptions

    Initialize Emulation               elf=${URI}/zephyr_pmsav8-overlapping-regions-test_fvp_baser_aemv8r_aarch32.elf-s_573792-14ad334a607d98b602f0f72522c8c22ba986b5da
    ...                                create_uart_tester=True

    # The app will try to load from 0xCAFEBEE0 in main. It was built with an additional region in
    # MPU <0xCAFEB000,0xCAFEBFFF> that overlaps a default DEVICE region <0x80000000,0xFFFFFFFF>.
    Execute Command                    sysbus Tag <0xCAFEBEE0,0xCAFEBEE3> "MPU_TEST" 0xDEADCAFE

    Wait For Line On Uart              *** Booting Zephyr OS build
    Wait For Line On Uart              Reading value from an address with overlapping MPU regions...

    # 4 is a fault code for the Translation Fault. It doesn't have a nice log in Zephyr.
    # See dump_fault in arch/arm/core/aarch32/cortex_a_r/fault.c.
    Wait For Line On Uart              DATA ABORT
    Wait For Line On Uart              Unknown (4)

Run Zephyr SMP Pi Sample On 4 Cores with GICv3
    [Tags]                             Demos

    Execute Command                    i @platforms/cpus/cortex-r52_smp_4.repl
    Execute Command                    sysbus LoadELF ${URI}/fvp_baser_aemv8r_aarch32--zephyr-arch-smp-pi.elf-s_610540-6034d4eb76ea1b158f34bdd92ffcff2365f2c2e6

    Execute Command                    showAnalyzer ${UART}
    Create Terminal Tester             ${UART}

    Wait For Line On Uart              All 16 threads executed by 4 cores

Run Zephyr SMP Pi Sample On 4 Cores with GICv2
    [Tags]                             Demos

    Execute Command                    mach create
    Execute Command                    machine LoadPlatformDescriptionFromString ${GIC_V2_SMP}
    Execute Command                    sysbus LoadELF ${URI}/fvp_baser_aemv8r_aarch32-gicv2--zephyr-arch-smp-pi.elf-s_597400-159126f83bc84cc4c34e1f4088774ba47fc0632e

    Execute Command                    showAnalyzer ${UART}
    Create Terminal Tester             ${UART}

    Wait For Line On Uart              All 16 threads executed by 4 cores
