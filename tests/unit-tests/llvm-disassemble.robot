*** Keywords ***

# WriteDoubleWord: 	reversed bytes
# Disassembly output:	spaces between bytes
DisasTest BE
    [Arguments]    ${hex_code}    ${mnemonic}=    ${operands}=    ${code_size}=4    ${hex_addr}=0

    ${hex_addr}=        Convert To Hex     ${hex_addr}    length=8    base=16

    ${b1}=              Get Substring      ${hex_code}    0    2
    ${b2}=              Get Substring      ${hex_code}    2    4
    ${b3}=              Get Substring      ${hex_code}    4    6
    ${b4}=              Get Substring      ${hex_code}    6    8

    ${b_write}=         Set Variable       ${b4}${b3}${b2}${b1}
    ${b_disas}=         Set Variable       ${b1}${b2}${b3}${b4}

    IF  ${code_size} > 4
        ${b_disas_4B+}=    Write Extra Bytes BE And Return Their Expected Output    ${hex_addr}    ${hex_code}
    ELSE
        ${b_disas_4B+}=    Set Variable    ${None}
    END
    ${b_disas}=         Set Variable If    ${code_size} > 4        ${b_disas}${b_disas_4B+}    ${b_disas}

    DisasTest Core      ${hex_addr}    ${b_write}    ${b_disas}    ${mnemonic}    ${operands}    ${code_size}


Write Extra Bytes BE And Return Their Expected Output
    [Arguments]    ${hex_addr}    ${hex_code}

    ${int}=                Convert To Integer    0x${hex_addr}
    ${int}=                Evaluate              $int + 4
    ${adjusted_addr}=      Convert To Hex        ${int}

    ${b5}=                 Get Substring         ${hex_code}     8    10
    ${b6}=                 Get Substring         ${hex_code}    10    12
    ${b7}=                 Get Substring         ${hex_code}    12    14
    ${b8}=                 Get Substring         ${hex_code}    14    16

    Execute Command        sysbus WriteDoubleWord 0x${adjusted_addr} 0x${b8}${b7}${b6}${b5}

    Return From Keyword    ${b5}${b6}${b7}${b8}


# WriteDoubleWord:	reversed words
# Disassembly output:	space between words
DisasTest Thumb
    [Arguments]    ${hex_code}    ${mnemonic}=    ${operands}=    ${code_size}=4    ${hex_addr}=0

    ${hex_addr}=      Convert To Hex    ${hex_addr}    length=8    base=16

    ${w1}=            Get Substring     ${hex_code}    0    4
    ${w2}=            Get Substring     ${hex_code}    4

    ${b_write}=       Set Variable      ${w2}${w1}
    ${b_disas}=       Set Variable      ${w1}${w2}

    DisasTest Core    ${hex_addr}    ${b_write}    ${b_disas}    ${mnemonic}    ${operands}    ${code_size}


DisasTest LE
    [Arguments]    ${hex_code}    ${mnemonic}=    ${operands}=    ${code_size}=4    ${hex_addr}=0

    ${hex_addr}=    Convert To Hex    ${hex_addr}    length=8    base=16

    DisasTest Core    ${hex_addr}    ${hex_code}    ${hex_code}    ${mnemonic}    ${operands}    ${code_size}


DisasTest Core
    [Arguments]    ${hex_addr}    ${code_write}    ${code_disas}    ${mnemonic}    ${operands}    ${code_size}

    Execute Command              sysbus WriteDoubleWord 0x${hex_addr} 0x${code_write}
    ${res}=                      Execute Command    sysbus.cpu DisassembleBlock 0x${hex_addr} ${code_size}

    # expect error if "$mnemonic" and "$operands" (without curly brackets!) are empty
    Run Keyword And Return If    $mnemonic == '' and $operands == ''        Should Match Regexp    ${res}    Disassembly error detected

    # compare DisassembleBlock output with the expected one; "(?i)" prefix causes ignoring case difference
    ${escaped_mnem}=             Regexp Escape      ${mnemonic}
    ${escaped_oper}=             Regexp Escape      ${operands}
    Should Match Regexp          ${res}             (?i)^0x${hex_addr}:\\s+${code_disas}\\s+${escaped_mnem}\\s+${escaped_oper}\\n+$


Create Machine
    [Arguments]    ${cpu}    ${model}

    # "extra" will be appended to the cpu creation string after cpuType (at least it has to close curly brackets opened before cpuType)
    ${extra}=          Set Variable       }

    # the last ${extra} field covers the "else" case, keeping the previous value of "extra"; by default, "else" case sets variables to "None"
    ${extra}=          Set Variable If    "${cpu}" == "CortexM"        ; nvic: nvic }; nvic: IRQControllers.NVIC    ${extra}
    ${extra}=          Set Variable If    "${cpu}" == "PowerPc64"      ; endianness: Endianess.LittleEndian }       ${extra}
    ${extra}=          Set Variable If    "${cpu}" == "RiscV32"        ; timeProvider: empty }                      ${extra}
    ${extra}=          Set Variable If    "${cpu}" == "RiscV64"        ; timeProvider: empty }                      ${extra}
    ${extra}=          Set Variable If    "${cpu}" == "X86"            ; lapic: empty }                             ${extra}

    Execute Command    mach create
    Execute Command    machine LoadPlatformDescriptionFromString "cpu: CPU.${cpu} @ sysbus { cpuType: \\"${model}\\" ${extra}"
    Execute Command    machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x50000 }"

Disassemble RV32IMA
    DisasTest LE           01212823    sw               s2, 16(sp)              # rv32i
    DisasTest LE           00b785b3    add              a1, a5, a1              # rv32i
    DisasTest LE           00008297    auipc            t0, 8                   # rv32i
    DisasTest LE           0000100F    fence.i                                  # Zifencei
    DisasTest LE           3401f173    csrrci           sp, mscratch, 3         # Zicsr
    DisasTest LE           02ab5c33    divu             s8, s6, a0              # rv32m
    DisasTest LE           0805252f    amoswap.w        a0, zero, (a0)          # rv32a

Disassemble RV32FD
    DisasTest LE           580123d3    fsqrt.s          ft7, ft2, rdn           # rv32f
    DisasTest LE           5a0123d3    fsqrt.d          ft7, ft2, rdn           # rv32d

Disassemble RV32C
    DisasTest LE           3fed        jal              -6              2       # rv32c

Disassemble RV64IMAC
    DisasTest LE           000a3a83    ld               s5, 0(s4)               # rv64i
    DisasTest LE           abcd8a9b    addiw            s5, s11, -1348          # rv64i
    DisasTest LE           02ab7c3b    remuw            s8, s6, a0              # rv64m
    DisasTest LE           e705b52f    amomaxu.d.aqrl   a0, a6, (a1)            # rv64a
    DisasTest LE           eabc        sd               a5, 80(a3)      2       # rv64c

Disassemble RV64FD
    DisasTest LE           d0312353    fcvt.s.lu        ft6, sp, rdn            # rv64f
    DisasTest LE           d2312353    fcvt.d.lu        ft6, sp, rdn            # rv64d

Disassemble RVV
    DisasTest LE           00057757    vsetvli          a4, a0, e8, m1, tu, mu 
    DisasTest LE           03058407    vle8ff.v         v8, (a1)
    DisasTest LE           4218a757    vfirst.m         a4, v1


*** Test Cases ***

# Keywords to disassemble single instruction
#
# DisasTest (BE|LE|Thumb)    HEX_CODE    [MNEMONIC]    [OPERANDS]    [CODE_SIZE=4]    [HEX_ADDR=00000000]
#    HEX_CODE                   the opcode to disassemble; don't prefix with "0x"
#    MNEMONIC, OPERANDS         expected disassembly results; expect empty result if both are empty
#    CODE_SIZE                  in bytes; max 8B instructions are supported
#    HEX_ADDR                   hex address of the instruction, verified with the disassembler output but not influencing the opcode itself; don't prefix with "0x"

Should Disassemble ARM Cortex-A
    Create Machine         Arm         arm926

    DisasTest LE           32855001    addlo    r5, r5, \#1     hex_addr=8000
    DisasTest LE           e1b00a00    lsls     r0, r0, \#20    hex_addr=813c
    DisasTest LE           1a00000a    bne      \#40

Should Disassemble ARM Cortex-M
    Create Machine         CortexM     cortex-m4

    DisasTest Thumb        f0230403    bic      r4, r3, \#3          hex_addr=2
    DisasTest Thumb        58c8        ldr      r0, [r1, r3]    2
    DisasTest Thumb        f44f426d    mov.w    r2, \#60672          hex_addr=9e8
    DisasTest Thumb        10b6        asrs     r6, r6, \#2     2    ad88

Should Disassemble RISCV32IMA
    Create Machine         RiscV32     rv32ima
    Disassemble RV32IMA

Should Disassemble RISCV32IMAC
    Create Machine         RiscV32     rv32imac
    Disassemble RV32IMA
    Disassemble RV32C

Should Disassemble RISCV32IMAFDC
    Create Machine         RiscV32     rv32imafdc
    Disassemble RV32IMA
    Disassemble RV32FD
    Disassemble RV32C

Should Disassemble RISCV32GC
    Create Machine         RiscV32     rv32gc
    Disassemble RV32IMA
    Disassemble RV32FD
    Disassemble RV32C

Should Disassemble RISCV32GV
    Create Machine         RiscV32     rv32gv
    Disassemble RV32IMA
    Disassemble RVV

Should Disassemble RISCV64IMAC
    Create Machine         RiscV64     rv64imac
    Disassemble RV32IMA
    Disassemble RV64IMAC

Should Disassemble RISCV64IMAFDC
    Create Machine         RiscV64     rv64imafdc
    Disassemble RV32IMA
    Disassemble RV32FD
    Disassemble RV64IMAC
    Disassemble RV64FD

Should Disassemble RISCV64GC
    Create Machine         RiscV64     rv64gc
    Disassemble RV32IMA
    Disassemble RV32FD
    Disassemble RV64IMAC
    Disassemble RV64FD

Should Disassemble RISCV64GCV
    Create Machine         RiscV64     rv64gcv
    Disassemble RV64IMAC
    Disassemble RVV

Should Disassemble PPC
    Create Machine         PowerPc     e200z6

    DisasTest BE           4800007c    b         .+124
    DisasTest BE           7f880040    cmplw     7, 8, 0    hex_addr=123
    DisasTest BE           7ce40034    cntlzw    4, 7

Should Disassemble PPC64 LE
    Create Machine         PowerPc64   620

    # DisasTest BE is used because of the output formatting
    # CPU is set as LE in Renode and LLVM's LE version of ppc64 is used
    DisasTest BE           18002389    lbz       9, 24(3)
    DisasTest BE           40202a7c    cmpld     10, 4
    DisasTest BE           71790248    bl        .+162160

Should Disassemble Sparc
    Create Machine         Sparc       leon3

    DisasTest BE           85e8a018    restore    %g2, 24, %g2    hex_addr=abc
    DisasTest BE           01000000    nop        hex_addr=abc
    DisasTest BE           10680047    ba         %xcc, 71

Should Disassemble X86
    Create Machine         X86         x86

    DisasTest BE           6b7b0c14            imull     $20, 12(%ebx), %edi
    DisasTest BE           45                  incl      %ebp                      1
    DisasTest BE           0fb7c0              movzwl    %ax, %eax                 3    cc
    DisasTest BE           66890cc516a9fd00    movw      %cx, 16623894(,%eax,8)    8    a
    DisasTest BE           0f011d5e00fc00      lidtl     16515166                  7    abd

Should Handle Illegal Instruction
    Create Machine         RiscV64     rv64g

    DisasTest LE           0
    DisasTest LE           0000

Should Handle Disassembly From Invalid Address
    Create Machine         RiscV64     rv64g

    # test with the valid address
    DisasTest LE           02051613    slli    a2, a0, 32    hex_addr=1234

    # check whether the output contains error if we only change the address to be outside "mem"
    Run Keyword And Expect Error    'Disassembly error detected*      DisasTest LE    02051613    slli    a2, a0, 32    hex_addr=02000000
