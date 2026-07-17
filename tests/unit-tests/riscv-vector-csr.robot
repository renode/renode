*** Variables ***
${starting_pc}  0x2000
${mtvec}  0x1010
${illegal_instruction}  0x2
${load_misaligned}  0x4
${store_misaligned}  0x6
${user_mode}  0x0
${supervisor_mode}  0x1
${hypervisor_mode}  0x2
${machine_mode}  0x3

*** Keywords ***
Create Machine
    [Arguments]  ${bitness}  ${init_pc}
    Execute Command  using sysbus
    Execute Command  mach create "risc-v"

    Execute Command  machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command  machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { timeProvider: clint; cpuType: \\"rv${bitness}imafd_zicsr_zifencei_c_v_zba_zbb_zbc_zbs_zfh_zacas_zcb\\" }"
    Execute Command  machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    IF  ${init_pc}
        Execute Command  cpu PC ${starting_pc}
        Execute Command  cpu SetRegister "mtvec" ${mtvec}
    END

Create Machine 32
    Create Machine  bitness=32  init_pc=True

Create Machine 64
    Create Machine  bitness=64  init_pc=True

Set Register
    [Arguments]  ${register}  ${value}
    Execute Command  cpu SetRegister ${register} ${value}

Register Should Be Equal
    [Arguments]  ${register}  ${value}
    ${register_value}=  Execute Command  cpu GetRegister ${register}
    Should Be Equal As Numbers  ${value}  ${register_value}

Change Privilege
    [Arguments]  ${mode}
    Set Register  "priv"  ${mode}

Assemble At Current Pc
    [Arguments]  ${program}
    ${length}=  Execute Command  cpu AssembleBlock `cpu PC` ${program}
    ${length}=  Convert To Integer  ${length}
    RETURN  ${length}

Run Assembly
    [Arguments]  ${program}  ${allow_trap}=False

    ${length}=  Assemble At Current Pc  ${program}
    ${pc}=  Execute Command  cpu PC
    ${current_pc}=  Convert To Integer  ${pc}
    ${last_pc}=  Evaluate  ${current_pc} + ${length}

    WHILE  ${current_pc} != ${last_pc}  limit=${length}
        ${current_pc}=  Execute Command  cpu Step
        ${current_pc}=  Convert To Integer  ${current_pc}
        IF  ${current_pc} == ${mtvec}
            IF  ${allow_trap}
                BREAK
            ELSE
                ${trap_pc}=  Execute Command  cpu GetRegister "mepc"
                ${mcause}=  Execute Command  cpu GetRegister "mcause"
                Fail  Trap Caught At ${trap_pc} Cause: ${mcause}
            END
        END
    END
    
Run Instruction
    [Arguments]  ${instruction}
    Assemble At Current Pc  ${instruction}
    Execute Command  cpu Step

Should Trap
    [Arguments]  ${cause}
    ${pc}=  Execute Command  cpu GetRegister "pc"
    Should Be Equal As Numbers  ${mtvec}  ${pc}
    ${mcause}=  Execute Command  cpu GetRegister "mcause"
    Should Be Equal As Numbers  ${mcause}  ${cause}


*** Test Cases ***
Should Trap On VXRM Write When MSTATUS.VS Is Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxrm, a0

    Create Machine 64
    Run Assembly  """${assembly}"""  allow_trap=True
    Should Trap  ${illegal_instruction}

Should Trap On VXSAT Write When MSTATUS.VS Is Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxsat, a0

    Create Machine 64
    Run Assembly  """${assembly}"""  allow_trap=True
    Should Trap  ${illegal_instruction}

Should Trap On VCSR Write When MSTATUS.VS Is Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vcsr, a0

    Create Machine 64
    Run Assembly  """${assembly}"""  allow_trap=True
    Should Trap  ${illegal_instruction}

Should Keep VXRM Upper Bits As Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxrm, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vxrm"   0x3

Should Keep VXSAT Upper Bits As Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxsat, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vxsat"   0x1

Should Keep VCSR Upper Bits As Zero
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vcsr, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vcsr"   0x7

Should Reflect VXSAT In VCSR
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxsat, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vcsr"   0x1

Should Reflect VXRM In VCSR
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vxrm, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vcsr"   0x6

Should Reflect VCSR In VXSAT And VXRM
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, -1
    ...                             csrw vcsr, a0

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "vxsat"   0x1
    Register Should Be Equal  "vxrm"   0x3

Should Reflect VSADD.VV Saturation In VCSR
     ${assembly}=                    Catenate  SEPARATOR=\n
     ...                             li a0, 127
     ...                             li a1, 127
     ...                             csrw vcsr, zero
     ...                             vsetvli t0, zero, e8, m1, ta, ma
     ...                             vmv.v.x v0, a0
     ...                             vmv.v.x v1, a1
     ...                             vsadd.vv v2, v0, v1

     Create Machine 64
     Set Register  "mstatus"  0x00000600
     Run Assembly  """${assembly}"""
     Register Should Be Equal  "vcsr"   0x1

Should Mark MSTATUS.VS As Dirty
    Create Machine 64
    Set Register  "mstatus"  0x00000200
    Run Instruction  "csrwi vcsr, 3"
    Register Should Be Equal  "mstatus"  0x00000600

Should Leave Enough VSTART Bits For Largest Possible Value
    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             li a0, 0xffffffffffffffff
    ...                             csrw vstart, a0
    ...                             csrr a0, vstart

    Create Machine 64
    Set Register  "mstatus"  0x00000600
    Execute Command  cpu VectorRegisterLength 256
    Run Assembly  """${assembly}"""
    Register Should Be Equal  "a0"  0xff
