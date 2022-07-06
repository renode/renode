*** Settings ***
Test Timeout                        2 minutes


*** Variables ***
${MTVEC}                            0x80080000

${RV32_PRIV10}=     SEPARATOR=
...  """                                                                ${\n}
...  cpu: CPU.RiscV32 @ sysbus                                          ${\n}
...  ${SPACE*4}cpuType: "rv32gcv"                                       ${\n}
...  ${SPACE*4}privilegeArchitecture: PrivilegeArchitecture.Priv1_10    ${\n}
...  ${SPACE*4}timeProvider: empty                                      ${\n}
...                                                                     ${\n}
...  dram: Memory.MappedMemory @ sysbus 0x80000000                      ${\n}
...  ${SPACE*4}size: 0x06400000                                         ${\n}
...  """


*** Keywords ***
Write Opcode To
    [Arguments]                         ${adress}   ${opcode}
    Execute Command                     sysbus WriteDoubleWord ${adress} ${opcode}

Create RV32PRIV10 Machine
    Execute Command                     using sysbus
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString ${RV32_PRIV10}

Prepare RV32 State
    Execute Command                     cpu MTVEC ${MTVEC}
    Execute Command                     cpu PC 0x80000000
    Execute Command                     cpu ExecutionMode SingleStepBlocking
    Execute Command                     start

Step Once And Ensure Not Trapped
    [Arguments]                         ${trap_adress}

    ${PC}=  Execute Command             cpu Step
    Should Not Be Equal As Integers     ${PC}  ${trap_adress}


*** Test Cases ***
Should Not Throw Exception After MRET in the NAPOT GRAIN32 Configuration
    Create RV32PRIV10 Machine
    Prepare RV32 State

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

    # Aligment
    Write Opcode To  0x80000000         0x13        # nop

    # Set up pmpaddr0
    Write Opcode To  0x80000004         0x800002b7  # lui      t0,0x80000
    Write Opcode To  0x80000008         0x12fd      # addi     t0,t0,-1    # t0 = 0x7fffffff
    Write Opcode To  0x8000000A         0x3b029073  # csrw     pmpaddr0,t0

    # Set up pmpcfg0
    Write Opcode To  0x8000000E         0x42fd      # li       t0,31
    Write Opcode To  0x80000010         0x3a029073  # csrw     pmpcfg0,t0

    Execute Command                     cpu MEPC 0x80000018
    Write Opcode To  0x80000014         0x30200073  # mret

    Execute Command                     cpu Step 7



    ################################
    #        PMP TEST START        #
    ################################

    # Test code execution from the PMP covered region
    Write Opcode To  0x80000018         0x13        # nop
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test loads from the PMP covered region
    Execute Command                     cpu SetRegisterUnsafe 8 0x80001000
    Write Opcode To  0x8000001c         0x00042483  # lw       s1, 0(s0)
    Step Once And Ensure Not Trapped    ${MTVEC}

    # Test writes to PMP covered region
    Write Opcode To  0x80000020         0x00942023  # sw       s1,0(s0)
    Step Once And Ensure Not Trapped    ${MTVEC}
