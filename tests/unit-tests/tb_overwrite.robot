*** Variables ***
# RISC-V registers
${a0}                         0xa
${a1}                         0xb
${a2}                         0xc
${a3}                         0xd

*** Keywords ***
Create Machine
    Execute Command        mach create
    Execute Command        machine LoadPlatformDescription @platforms/cpus/litex_ibex.repl
    Execute Command        using sysbus

    Execute Command        cpu PC 0x0
    Execute Command        cpu ExecutionMode SingleStepBlocking
    Execute Command        sysbus WriteDoubleWord 0x0 0x800593  # 0x0000: li a1, 0x8
    Execute Command        sysbus WriteDoubleWord 0x4 0x13      # 0x0004: nop
    Execute Command        sysbus WriteDoubleWord 0x8 0x500e7   # 0x0008: jalr a0
    Execute Command        sysbus WriteDoubleWord 0xC 0x58067   # 0x000C: jr a1

# Different page
    Execute Command        sysbus WriteDoubleWord 0x1000 0x13   # 0x1000: nop
    Execute Command        sysbus WriteDoubleWord 0x1004 0x8067 # 0x1004: ret
# Same page
    Execute Command        sysbus WriteDoubleWord 0x10 0x13     # 0x10: nop
    Execute Command        sysbus WriteDoubleWord 0x14 0x8067   # 0x14: ret

Overwrite With Nops
    [Arguments]     ${addr}    ${count}
    FOR  ${offset}  IN RANGE  ${count}
        Execute Command       sysbus WriteDoubleWord ${addr} 0x13
        ${addr}=              Evaluate   ${addr} + 4
    END

Overwrite With Nops As Guest
# Must be called right before the jump `jalr a0`
    [Arguments]            ${addr}  ${count}
    ${ptr}=                Set Variable  0x2000
    ${tmp_ptr}=            Set Variable  ${ptr}
    ${prev_a0_value}=      Execute Command  sysbus.cpu GetRegisterUnsafe ${a0}
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a0} ${ptr}
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a2} 0x13
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a3} ${addr}

    # Write instructions overwriting requested range
    FOR  ${repetition}  IN RANGE  ${count}
        Execute Command       sysbus WriteDoubleWord ${tmp_ptr} 0x6a123   # 0x20xx: sw x0, 2(a3)
        ${tmp_ptr}=           Evaluate   ${tmp_ptr} + 4
        Execute Command       sysbus WriteDoubleWord ${tmp_ptr} 0xc6a023  # 0x20xx: sw a2, 0(a3)
        ${tmp_ptr}=           Evaluate   ${tmp_ptr} + 4
        Execute Command       sysbus WriteDoubleWord ${tmp_ptr} 0x468693  # 0x20xx: addi a3, a3, 4
        ${tmp_ptr}=           Evaluate   ${tmp_ptr} + 4
    END
    Execute Command        sysbus WriteDoubleWord ${tmp_ptr} 0x8067  # ret

    # Execute them
    ${insn_to_exec}=       Evaluate   ${count} * 3 + 3
    Execute Command        sysbus.cpu Step ${insn_to_exec}

    # Assert the write was succesfull
    ${insn_at_addr}=       Execute Command  sysbus ReadDoubleWord ${addr}
    Should Be Equal As Integers  ${insn_at_addr}  0x13

    # Restore significant registers
    Execute Command     sysbus.cpu SetRegisterUnsafe ${a0} ${prev_a0_value}

Assert PC Equals
    [Arguments]            ${expected}
    ${pc}=                 Execute Command  cpu PC
    Should Be Equal As Integers  ${pc}  ${expected}

*** Test Cases ***
Shoud Invalidate Other Page When Overwritten Using Sysbus
    Create Machine
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a0} 0x1000

    Start Emulation
    Execute Command        cpu Step 3
    Assert PC Equals       0x1000
    Execute Command        cpu Step 3
    Assert PC Equals       0x08

    Overwrite With Nops    0x1004  2

    Execute Command        cpu Step 3
    Assert PC Equals       0x1008

Shoud Invalidate The Same Page When Overwritten Using Sysbus
    Create Machine
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a0} 0x10

    Start Emulation
    Execute Command        cpu Step 3
    Assert PC Equals       0x10
    Execute Command        cpu Step 3
    Assert PC Equals       0x08

    Overwrite With Nops    0x14  3

    Execute Command        cpu Step 3
    Assert PC Equals       0x18

Should Invalidate Other Page When Overwritten By Guest
    Create Machine
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a0} 0x1000

    Start Emulation
    Execute Command        cpu Step 3
    Assert PC Equals       0x1000
    Execute Command        cpu Step 3
    Assert PC Equals       0x8

    Overwrite With Nops As Guest   0x1004  2

    Execute Command        cpu Step 3
    Assert PC Equals       0x1008

Should Invalidate The Same Page When Overwritten By Guest
    Create Machine
    Execute Command        sysbus.cpu SetRegisterUnsafe ${a0} 0x10

    Start Emulation
    Execute Command        cpu Step 3
    Assert PC Equals       0x10
    Execute Command        cpu Step 3
    Assert PC Equals       0x8

    Overwrite With Nops As Guest   0x14  2

    Execute Command        cpu Step 3
    Assert PC Equals       0x18

