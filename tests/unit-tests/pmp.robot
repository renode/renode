*** Variables ***
${MTVEC}                            0x80080000

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


*** Keywords ***
Create RV32PRIV10 Machine
    Execute Command                     using sysbus
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString ${RV32_PRIV10}


Step Once And Ensure Not Trapped
    [Arguments]                         ${trap_adress}

    ${PC}=  Execute Command             cpu Step
    Should Not Be Equal As Integers     ${PC}  ${trap_adress}


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
    Execute Command                     cpu PC 0x80000000
    ${machine_assembly}=                Catenate  SEPARATOR=\n
    ...                                 # Set up pmpaddr0 (0x7fffffff)
    ...                                 lui t0, 0x80000
    ...                                 addi t0, t0, -1
    ...                                 csrw pmpaddr0, t0
    ...                                 # Set up pmpcfg0 (0b11111)
    ...                                 li t0, 31
    ...                                 csrw pmpcfg0, t0
    ...                                 mret

    Execute Command                     cpu AssembleBlock 0x80000000 "${machine_assembly}"
    Execute Command                     cpu MEPC 0x80001000

    ${user_assembly}=                   Catenate  SEPARATOR=\n
    ...                                 # Execution from protected region
    ...                                 nop
    ...                                 # Load from protected region
    ...                                 lui s0, 0x80002
    ...                                 lw s1, 0(s0)
    ...                                 # Store to protected region
    ...                                 sw s1, 4(s0)
    
    Execute Command                     cpu AssembleBlock 0x80001000 "${user_assembly}"

    # Step to user mode
    Execute Command                     cpu Step 6

    ################################
    #        PMP TEST START        #
    ################################

    # Test code execution from the PMP covered region
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test loads from the PMP covered region
    Execute Command                     sysbus WriteDoubleWord 0x80002000 0x65657a
    Execute Command                     cpu Step
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test writes to PMP covered region
    Step Once And Ensure Not Trapped    ${MTVEC}
    ${num}=  Execute Command            sysbus ReadDoubleWord 0x80002004
    Should Be Equal As Integers         ${num}  0x65657a
