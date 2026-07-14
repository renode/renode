*** Variables ***
${starting_pc}                      0x2000
${mtvec}                            0x1010
${illegal_instruction}              0x2
${load_misaligned}                  0x4
${store_misaligned}                 0x6
${user_mode}                        0x0
${supervisor_mode}                  0x1
${hypervisor_mode}                  0x2
${machine_mode}                     0x3

*** Keywords ***
Create Machine
    [Arguments]                     ${bitness}  ${init_pc}
    Execute Command                 using sysbus
    Execute Command                 mach create "risc-v"

    Execute Command                 machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { timeProvider: clint; cpuType: \\"rv${bitness}imafd_zicsr_zifencei_c_v_zba_zbb_zbc_zbs_zfh_zacas_zcb\\" }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    IF  ${init_pc}
        Execute Command                 cpu PC ${starting_pc}
        Execute Command                 cpu SetRegister "mtvec" ${mtvec}
    END

Create Machine 32
    Create Machine                  bitness=32  init_pc=True

Create Machine 64
    Create Machine                  bitness=64  init_pc=True

Set Register
    [Arguments]                     ${register}  ${value}
    Execute Command                 cpu SetRegister ${register} ${value}

Register Should Be Equal
    [Arguments]                     ${register}  ${value}
    ${register_value}=              Execute Command  cpu GetRegister ${register}
    Should Be Equal As Numbers      ${value}  ${register_value}

Change Privilege
    [Arguments]                     ${mode}
    Set Register                    "priv"  ${mode}

Assemble At Current Pc
    [Arguments]                     ${program}
    ${length}=                      Execute Command  cpu AssembleBlock `cpu PC` ${program}
    ${length}=                      Convert To Integer  ${length}
    RETURN                          ${length}

Run Assembly
    [Arguments]                     ${program}
    ${length}=                      Assemble At Current Pc  ${program}
    ${pc}=                          Execute Command  cpu PC
    ${current_pc}=                  Convert To Integer  ${pc}
    ${last_pc}=                     Evaluate  ${current_pc} + ${length}

    WHILE  ${current_pc} != ${last_pc}  limit=${length}
        ${current_pc}=                  Execute Command  cpu Step
        ${current_pc}=                  Convert To Integer  ${current_pc}
        IF  ${current_pc} == ${mtvec} # Don't fail on traps
            BREAK
        END
    END

Run Instruction
    [Arguments]                     ${instruction}
    Assemble At Current Pc          ${instruction}
    Execute Command                 cpu Step

Should Trap
    [Arguments]                     ${cause}
    ${pc}=                          Execute Command  cpu GetRegister "pc"
    Should Be Equal As Numbers      ${mtvec}  ${pc}
    ${mcause}=                      Execute Command  cpu GetRegister "mcause"
    Should Be Equal As Numbers      ${mcause}  ${cause}

Untrap
    ${mepc}=                        Execute Command  cpu GetRegister "mepc"
    Execute Command                 cpu SetRegister "pc" ${mepc}

Should Not Trap
    ${pc}=                          Execute Command  cpu GetRegister "pc"
    Should Not Be Equal As Numbers  ${mtvec}  ${pc}

*** Test Cases ***
Should Fail On Counter Access
    Create Machine 64

    Change Privilege                ${machine_mode}
    Run Assembly                    "li t0, 0; csrw mcounteren, t0"

    Change Privilege                ${supervisor_mode}
    Run Assembly                    "li t0, 7; csrw scounteren, t0"

    Change Privilege                ${user_mode}

    Run Assembly                    "csrr a0, mcycle"
    Should Trap                     ${illegal_instruction}

    Untrap
    Change Privilege                ${user_mode}
    Run Assembly                    "rdinstret a0"
    Should Trap                     ${illegal_instruction}

Should Increment MCYCLE RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             csrr a1, mcycle
    ...                             nop
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0x2

Should Increment MINSTRET RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             csrr a1, minstret
    ...                             nop
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0x2

Should Increment MCYCLE RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             csrr a1, mcycle
    ...                             nop
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0x2

Should Increment MINSTRET RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             csrr a1, minstret
    ...                             nop
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0x2

Should Inhibit MCYCLE RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 1
    ...                             csrw mcountinhibit, a0
    ...                             csrr a1, mcycle
    ...                             nop
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0

Should Inhibit MINSTRET RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 4
    ...                             csrw mcountinhibit, a0
    ...                             csrr a1, minstret
    ...                             nop
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0

Should Inhibit MCYCLE RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 1
    ...                             csrw mcountinhibit, a0
    ...                             csrr a1, mcycle
    ...                             nop
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0

Should Inhibit MINSTRET RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 4
    ...                             csrw mcountinhibit, a0
    ...                             csrr a1, minstret
    ...                             nop
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  0

Should Inhibit MCYCLE After Write Finishes RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 1
    ...                             li t0, 0
    ...                             csrr a1, mcycle
    ...                             csrw mcountinhibit, a0
    ...                             nop
    ...                             csrw mcountinhibit, t0
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  2

Should Inhibit MINSTRET After Write Finishes RV64
    Create Machine 64

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 4
    ...                             li t0, 0
    ...                             csrr a1, minstret
    ...                             csrw mcountinhibit, a0
    ...                             nop
    ...                             csrw mcountinhibit, t0
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  2

Should Inhibit MCYCLE After Write Finishes RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 1
    ...                             li t0, 0
    ...                             csrr a1, mcycle
    ...                             csrw mcountinhibit, a0
    ...                             nop
    ...                             csrw mcountinhibit, t0
    ...                             csrr a2, mcycle
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  2

Should Inhibit MINSTRET After Write Finishes RV32
    Create Machine 32

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 4
    ...                             li t0, 0
    ...                             csrr a1, minstret
    ...                             csrw mcountinhibit, a0
    ...                             nop
    ...                             csrw mcountinhibit, t0
    ...                             csrr a2, minstret
    ...                             sub a3, a2, a1
    Run Assembly                    """${assembly}"""

    Register Should Be Equal        "a3"  2

Should Trap On SFENCE.VMA In User Mode RV64
    Create Machine 64

    Change Privilege                ${user_mode}

    Run Assembly                    "sfence.vma x0, x0"
    Should Trap                     ${illegal_instruction}

Should Trap On SFENCE.VMA In User Mode RV32
    Create Machine 32

    Change Privilege                ${user_mode}

    Run Assembly                    "sfence.vma x0, x0"
    Should Trap                     ${illegal_instruction}

Should Trap On Sret When MSTATUS.TSR Is One RV64
    Create Machine 64

    Change Privilege                ${supervisor_mode}

    Set Register                    "mstatus"  0x00400000
    Set Register                    "sepc"  0x0000bad0
    Run Instruction                 "sret"
    Should Trap                     ${illegal_instruction}

Should Trap On Sret When MSTATUS.TSR Is One RV32
    Create Machine 32

    Change Privilege                ${supervisor_mode}

    Set Register                    "mstatus"  0x00400000
    Set Register                    "sepc"  0x0000bad0
    Run Instruction                 "sret"
    Should Trap                     ${illegal_instruction}

Should Trap On SATP Write When TVM Is One
    Create Machine 64

    Set Register                    "mstatus"  0x00100000
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "li a0, 0x0FFFF00000000000"
    Run Instruction                 "csrw satp, a0"
    Should Trap                     ${illegal_instruction}

Should Trap On SATP Read When TVM Is One
    Create Machine 64

    Set Register                    "mstatus"  0x00100000
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "csrr a0, satp"
    Should Trap                     ${illegal_instruction}

Should Trap On SFENCE.VMA When TVM Is One
    Create Machine 64

    Set Register                    "mstatus"  0x00100000
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "sfence.vma x0, x0"
    Should Trap                     ${illegal_instruction}

Should Not Trap On Sret When MSTATUS.TSR Is Zero RV64
    Create Machine 64

    Change Privilege                ${supervisor_mode}

    Set Register                    "mstatus"  0x0
    Set Register                    "sepc"  0x0000bad0
    Run Instruction                 "sret"
    Should Not Trap

Should Not Trap On Sret When MSTATUS.TSR Is Zero RV32
    Create Machine 32

    Change Privilege                ${supervisor_mode}

    Set Register                    "mstatus"  0x0
    Set Register                    "sepc"  0x0000bad0
    Run Instruction                 "sret"
    Should Not Trap

Should Not Trap On SATP Write When TVM Is Zero
    Create Machine 64

    Set Register                    "mstatus"  0x0
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "li a0, 0x0FFFF00000000000"
    Run Instruction                 "csrw satp, a0"
    Should Not Trap

Should Not Trap On SATP Read When TVM Is Zero
    Create Machine 64

    Set Register                    "mstatus"  0x0
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "csrr a0, satp"
    Should Not Trap

Should Not Trap On SFENCE.VMA When TVM Is Zero
    Create Machine 64

    Set Register                    "mstatus"  0x0
    Change Privilege                ${supervisor_mode}

    Run Instruction                 "sfence.vma x0, x0"
    Should Not Trap
