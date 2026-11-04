*** Variables ***
${PC}                               0x80000000
${MEPC}                             0x80001000
${MTVEC}                            0x80080000
${DUMMY_VALUE}                      0x65657a
${INSTRUCTION_ACCESS_FAULT}         0x1

${RV32_PRIV10}=     SEPARATOR=${\n}
...  """
...  cpu: CPU.RiscV32 @ sysbus
...  ${SPACE*4}cpuType: "rv32gcv"
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10
...  ${SPACE*4}timeProvider: empty
...
...  dram: Memory.MappedMemory @ sysbus 0x80000000
...  ${SPACE*4}size: 0x06400000
...  """
${RV64_PRIV10}=     SEPARATOR=${\n}
...  """
...  cpu: CPU.RiscV64 @ sysbus
...  ${SPACE*4}cpuType: "rv64gcv"
...  ${SPACE*4}pmpEntryCount: 16
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10
...  ${SPACE*4}timeProvider: empty
...
...  dram: Memory.MappedMemory @ sysbus 0x80000000
...  ${SPACE*4}size: 0x06400000
...  """
${RV32_NO_PMP}=     SEPARATOR=${\n}
...  """
...  cpu: CPU.RiscV32 @ sysbus
...  ${SPACE*4}cpuType: "rv32gcv"
...  ${SPACE*4}pmpEntryCount: 0
...  ${SPACE*4}timeProvider: empty
...
...  dram: Memory.MappedMemory @ sysbus 0x80000000
...  ${SPACE*4}size: 0x06400000
...  """

*** Keywords ***
Create RV32PRIV10 Machine
    Execute Command                     using sysbus
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString ${RV32_PRIV10}

Create RV64PRIV10 Machine
    Execute Command                     using sysbus
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString ${RV64_PRIV10}

Create RV32 No PMP Machine
    Execute Command                     using sysbus
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString ${RV32_NO_PMP}

Step Once And Ensure Not Trapped
    [Arguments]                         ${trap_adress}

    ${PC}=  Execute Command             cpu Step
    Should Not Be Equal As Integers     ${PC}  ${trap_adress}

Enter User Mode Without PMP Configuration
    Execute Command                     cpu MTVEC ${MTVEC}
    Execute Command                     cpu PC ${PC}
    Execute Command                     cpu MEPC ${MEPC}
    ${machine_assembly}=                Catenate  SEPARATOR=\n
    ...                                 # Set mstatus.MPP to U-mode
    ...                                 lui t0, 0x2
    ...                                 addi t0, t0, -2048
    ...                                 csrc mstatus, t0
    ...                                 mret
    Execute Command                     cpu AssembleBlock ${PC} "${machine_assembly}"
    Execute Command                     cpu AssembleBlock ${MEPC} "nop"
    Execute Command                     cpu AssembleBlock ${MTVEC} "j ."

    ${pc}=  Execute Command             cpu Step 4
    Should Be Equal As Integers         ${pc}  ${MEPC}

*** Test Cases ***
Should Not Throw Exception After MRET in the NAPOT GRAIN32 Configuration
    Create RV32PRIV10 Machine

    ####################################
    # PMP Configuration:               #
    # Rules : 1 (pmpaddr0 + pmpcfg0)   #
    # Mode  : NAPOT                    #
    # Grain : 32                       #
    #                                  #
    # Expected configuration:          #
    # - sa    = 0x0                    #
    # - ea    = 0xFFFFFFFF             #
    # - privs = R/W/X                  #
    # - lock  = false                  #
    ####################################

    Execute Command                     cpu MTVEC ${MTVEC}
    Execute Command                     cpu PC ${PC}
    ${machine_assembly}=                Catenate  SEPARATOR=\n
    ...                                 # Set up pmpaddr0 (0x7fffffff)
    ...                                 lui t0, 0x80000
    ...                                 addi t0, t0, -1
    ...                                 csrw pmpaddr0, t0
    ...                                 # Set up pmpcfg0 (0b11111)
    ...                                 li t0, 31
    ...                                 csrw pmpcfg0, t0
    ...                                 mret

    Execute Command                     cpu AssembleBlock ${PC} "${machine_assembly}"
    Execute Command                     cpu MEPC ${MEPC}

    ${user_assembly}=                   Catenate  SEPARATOR=\n
    ...                                 # Execution from protected region
    ...                                 nop
    ...                                 # Load from protected region
    ...                                 lui s0, 0x80002
    ...                                 lw s1, 0(s0)
    ...                                 # Store to protected region
    ...                                 sw s1, 4(s0)
    
    Execute Command                     cpu AssembleBlock ${MEPC} "${user_assembly}"

    # Step to user mode
    Execute Command                     cpu Step 6

    ################################
    #        PMP TEST START        #
    ################################

    # Test code execution from the PMP covered region
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test loads from the PMP covered region
    Execute Command                     sysbus WriteDoubleWord 0x80002000 ${DUMMY_VALUE}
    Execute Command                     cpu Step
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test writes to PMP covered region
    Step Once And Ensure Not Trapped    ${MTVEC}
    ${num}=  Execute Command            sysbus ReadDoubleWord 0x80002004
    Should Be Equal As Integers         ${num}  ${DUMMY_VALUE}

Should Trap On Odd pmpcfg Access In 64-bit Mode
    Create RV64PRIV10 Machine
    Execute Command                     cpu PC ${PC}
    # Not using `AssembleBlock` here because LLVM tries to outsmart us and prevents us from using pmpcfg1 in RV64
    Execute Command                     sysbus WriteDoubleWord ${PC} 0x3A129073  # `csrw pmpcfg1, 0`
    Create Log Tester                   5
    Execute Command                     cpu Step
    Wait For Log Entry                  Attempted illegal write to pmpcfg register with odd-numbered index (1)

Should Trap On Out-of-Bound pmpaddr
    Create RV64PRIV10 Machine
    Execute Command                     cpu PC ${PC}
    Execute Command                     cpu AssembleBlock ${PC} "csrw pmpaddr42, 0"
    Create Log Tester                   5
    Execute Command                     cpu Step
    Wait For Log Entry                  Attempted illegal write to pmpaddr register beyond entry count (42, entry count is 16)

Should Deny User Mode Access When All PMP Entries Are OFF
    Create RV32PRIV10 Machine
    Enter User Mode Without PMP Configuration

    # Unmatched U-mode fetch fails when PMP entries are implemented, even if all are OFF
    ${pc}=  Execute Command             cpu Step
    Should Be Equal As Integers         ${pc}  ${MTVEC}
    ${mcause}=  Execute Command         cpu MCAUSE
    Should Be Equal As Integers         ${mcause}  ${INSTRUCTION_ACCESS_FAULT}
    ${mepc}=  Execute Command           cpu MEPC
    Should Be Equal As Integers         ${mepc}  ${MEPC}

Should Allow User Mode Access When No PMP Entries Are Implemented
    Create RV32 No PMP Machine
    Enter User Mode Without PMP Configuration

    Step Once And Ensure Not Trapped    ${MTVEC}
