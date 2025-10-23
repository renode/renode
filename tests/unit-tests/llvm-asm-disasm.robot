*** Variables ***
${initial_pc}                       0x0

*** Keywords ***
# WriteDoubleWord:  reversed bytes
# Disassembly output:  spaces between bytes
DisasTest BE
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0  ${flags}=0

    ${hex_addr}=                    Convert To Hex  ${hex_addr}  length=8  base=16

    ${b1}=                          Get Substring  ${hex_code}  0  2
    ${b2}=                          Get Substring  ${hex_code}  2  4
    ${b3}=                          Get Substring  ${hex_code}  4  6
    ${b4}=                          Get Substring  ${hex_code}  6  8

    ${b_write}=                     Set Variable  ${b4}${b3}${b2}${b1}
    ${b_disas}=                     Set Variable  ${b1}${b2}${b3}${b4}

    IF  ${code_size} > 4
        ${b_disas_4B+}=                 Write Extra Bytes BE And Return Their Expected Output  ${hex_addr}  ${hex_code}
    ELSE
        ${b_disas_4B+}=                 Set Variable  ${None}
    END
    ${b_disas}=                     Set Variable If  ${code_size} > 4  ${b_disas}${b_disas_4B+}  ${b_disas}

    DisasTest Core                  ${hex_addr}  ${b_write}  ${b_disas}  ${mnemonic}  ${operands}  ${code_size}  ${flags}

RoundTrip BE
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0  ${flags}=0  ${reverse}=True

    IF  ${reverse}
        ${expected}=                    Reverse Bytes  ${{$hex_code[:int($code_size) * 2]}}
    ELSE
        ${expected}=                    Set Variable  ${hex_code}
    END
    AsTest                          ${expected}  ${mnemonic}  ${operands}  ${flags}  0x${hex_addr}
    DisasTest BE                    ${hex_code}  ${mnemonic}  ${operands}  ${code_size}  ${hex_addr}  ${flags}

Write Extra Bytes BE And Return Their Expected Output
    [Arguments]                     ${hex_addr}  ${hex_code}

    ${int}=                         Convert To Integer  0x${hex_addr}
    ${int}=                         Evaluate  $int + 4
    ${adjusted_addr}=               Convert To Hex  ${int}

    ${b5}=                          Get Substring  ${hex_code}  8  10
    ${b6}=                          Get Substring  ${hex_code}  10  12
    ${b7}=                          Get Substring  ${hex_code}  12  14
    ${b8}=                          Get Substring  ${hex_code}  14  16

    Execute Command                 sysbus WriteDoubleWord 0x${adjusted_addr} 0x${b8}${b7}${b6}${b5}

    Return From Keyword             ${b5}${b6}${b7}${b8}

Reverse Bytes
    [Arguments]                     ${hex_str}  ${group_size}=${2}

    ${len}=                         Get Length  ${hex_str}
    ${out}=                         Create List
    FOR  ${i}  IN RANGE  0  ${len}  ${group_size}
        ${byte}=                        Get Substring  ${hex_str}  ${i}  ${{$i+$group_size}}
        Append To List                  ${out}  ${byte}
    END
    Reverse List                    ${out}

    [Return]                        ${{"".join($out)}}

# WriteDoubleWord:  reversed words
# Disassembly output:  space between words

DisasTest Thumb
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0

    ${hex_addr}=                    Convert To Hex  ${hex_addr}  length=8  base=16

    ${w1}=                          Get Substring  ${hex_code}  0  4
    ${w2}=                          Get Substring  ${hex_code}  4

    ${b_write}=                     Set Variable  ${w2}${w1}
    ${b_disas}=                     Set Variable  ${w1}${w2}

    # `flags` is an internal parameter use by Renode in LLVMArchitectureMapping.cs:GetTripleAndModelKey to choose
    # the correct LLVM triple that represents the ARM* processor's state:
    #  - bit 0 specifies whether we're in Thumb mode  -  both for ARMv7 and ARMv8
    #  - bit 1 specifies whether we're in AArch32/32-bit mode (when set) or AArch64/64-bit mode (when unset) for ARMv8
    # Since the ARMv7 branch only checks `flags > 0` to switch to Thumb, and the ARMv8 branch _requires_ both bits
    # to be set for Thumb mode (no 64-bit Thumb), we set flags to 3 = 0b11, ie. "32-bit Thumb", to guarantee Thumb mode
    DisasTest Core                  ${hex_addr}  ${b_write}  ${b_disas}  ${mnemonic}  ${operands}  ${code_size}  flags=3

RoundTrip Thumb
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0

    # For Thumb, reverse the bytes in each word
    ${expected}=                    Reverse Bytes  ${hex_code}
    ${expected}=                    Reverse Bytes  ${expected}  group_size=${4}
    # See comment in `DisasTest Thumb` for meaning of flags
    AsTest                          ${expected}  ${mnemonic}  ${operands}  address=0x${hex_addr}  flags=3
    DisasTest Thumb                 ${hex_code}  ${mnemonic}  ${operands}  ${code_size}  ${hex_addr}

DisasTest LE
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0

    ${hex_addr}=                    Convert To Hex  ${hex_addr}  length=8  base=16

    DisasTest Core                  ${hex_addr}  ${hex_code}  ${hex_code}  ${mnemonic}  ${operands}  ${code_size}

RoundTrip LE
    [Arguments]                     ${hex_code}  ${mnemonic}=  ${operands}=  ${code_size}=4  ${hex_addr}=0

    ${expected}=                    Reverse Bytes  ${{$hex_code[:int($code_size) * 2]}}
    AsTest                          ${expected}  ${mnemonic}  ${operands}  address=0x${hex_addr}
    DisasTest LE                    ${hex_code}  ${mnemonic}  ${operands}  ${code_size}  ${hex_addr}

DisasTest Core
    [Arguments]                     ${hex_addr}  ${code_write}  ${code_disas}  ${mnemonic}  ${operands}  ${code_size}  ${flags}=0

    Execute Command                 sysbus WriteDoubleWord 0x${hex_addr} 0x${code_write}
    ${res}=                         Execute Command  sysbus.cpu DisassembleBlock 0x${hex_addr} ${code_size} ${flags}

    # expect error if "$mnemonic" and "$operands" (without curly brackets!) are empty
    Run Keyword And Return If       $mnemonic == '' and $operands == ''  Should Match Regexp  ${res}  Disassembly error detected

    # compare DisassembleBlock output with the expected one; "(?i)" prefix causes ignoring case difference
    ${escaped_mnem}=                Regexp Escape  ${mnemonic}
    ${escaped_oper}=                Regexp Escape  ${operands}
    Should Match Regexp             ${res}  (?i)^0x${hex_addr}:\\s+${code_disas}\\s+${escaped_mnem}\\s+${escaped_oper}\\n+$

AsTest
    [Arguments]                     ${expected}  ${mnemonic}  ${operands}=  ${flags}=0  ${address}=0

    ${len}=                         Execute Command  sysbus.cpu AssembleBlock ${address} "${mnemonic} ${operands}" ${flags}
    ${bytes}=                       Execute Command  sysbus ReadBytes ${address} ${len}

    # This string is safe to eval because it's formatted as a Python list by PrintActionResult in MonitorCommands.cs
    ${hex_bytes}=                   Evaluate  "".join("%02x"%b for b in ${bytes})

    # Reverse the bytes for a big-endian bus because the expected strings in the test cases are formatted
    # as if they had been read by ReadDoubleWord
    ${bus_endian}=                  Execute Command  sysbus Endianess
    ${bus_endian}=                  Get Line  ${bus_endian}  0
    IF  "${bus_endian}" == "BigEndian"
        ${hex_bytes}=                   Reverse Bytes  ${hex_bytes}
    END

    Should Be Equal                 ${hex_bytes}  ${expected}

Execute Instruction
    [Arguments]                     ${instruction}
    Execute Command                 cpu PC ${initial_pc}
    Execute Command                 cpu AssembleBlock ${initial_pc} "${instruction}"
    Execute Command                 cpu Step 1

Memory Should Be Equal
    [Arguments]                     ${address}  ${value}
    ${res}=                         Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers      ${res}  ${value}

# Ordinary 'Register Should Be Equal  ${register_number}  ${value}' checks register with number one below than expected
Xtensa Register Should Be Equal
    [Arguments]                     ${register}  ${value}  ${cpu}=cpu
    ${res}=                         Execute Command  ${cpu} GetRegister '${register}'
    Should Be Equal As Numbers      ${value}  ${res}

Create Machine
    [Arguments]                     ${cpu}  ${model}

    # "extra" will be appended to the cpu creation string after cpuType (at least it has to close curly brackets opened before cpuType)
    ${extra}=                       Set Variable  }

    ${ARMv8_gic}=                   Set Variable  genericInterruptController: gic }; gic: IRQControllers.ARM_GenericInterruptController @ { sysbus new Bus.BusMultiRegistration { address: 0x8000000; size: 0x010000; region: \\"distributor\\" }; sysbus new IRQControllers.ArmGicRedistributorRegistration { attachedCPU: cpu; address: 0x80a0000 } } { [0-1] -> cpu@[0-1]; architectureVersion: .GICv3; supportsTwoSecurityStates: true }
    # the last ${extra} field covers the "else" case, keeping the previous value of "extra"; by default, "else" case sets variables to "None"
    ${extra}=                       Set Variable If  "${cpu}" == "CortexM"  ; nvic: nvic }; nvic: IRQControllers.NVIC  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "ARMv8A"  ; ${ARMv8_gic}  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "ARMv8R"  ; ${ARMv8_gic}  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "PowerPc64"  ; endianness: Endianess.LittleEndian }  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "RiscV32"  ; timeProvider: empty }  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "RiscV64"  ; timeProvider: empty }  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "X86"  ; lapic: empty }  ${extra}
    ${extra}=                       Set Variable If  "${cpu}" == "X86_64"  ; lapic: empty }  ${extra}

    Execute Command                 mach create
    IF  any(x in "${cpu}" for x in ("PowerPc", "Sparc"))
        Execute Command                 machine LoadPlatformDescriptionFromString "sysbus: { Endianess: Endianess.BigEndian }"
    END
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.${cpu} @ sysbus { cpuType: \\"${model}\\" ${extra}"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x50000 }"

Assemble And Disassemble RV32IMA
    [Arguments]                     ${compressed}=False

    # Compressed format will be generated by the assembler if the core has the C extension
    # and is only accepted by the disassembler if the core has the C extension. The disassembler
    # output doesn't explicitly indicate the compressed instruction (c.sw, c.add)
    IF  ${compressed}
        RoundTrip LE                    c84a  sw  s2, 16(sp)  2  # rv32c
        RoundTrip LE                    95be  add  a1, a1, a5  2  # rv32c
    ELSE
        RoundTrip LE                    01212823  sw  s2, 16(sp)  # rv32i
        RoundTrip LE                    00b785b3  add  a1, a5, a1  # rv32i
    END

    # The uncompressed forms should be accepted by the disassembler even with the C extension
    DisasTest LE                    01212823  sw  s2, 16(sp)  # rv32i
    DisasTest LE                    00b785b3  add  a1, a5, a1  # rv32i

    RoundTrip LE                    00008297  auipc  t0, 8  # rv32i
    RoundTrip LE                    0000100f  fence.i  # Zifencei
    RoundTrip LE                    3401f173  csrrci  sp, mscratch, 3  # Zicsr
    RoundTrip LE                    02ab5c33  divu  s8, s6, a0  # rv32m
    RoundTrip LE                    0805252f  amoswap.w  a0, zero, (a0)  # rv32a

Assemble And Disassemble RV32FD
    RoundTrip LE                    580123d3  fsqrt.s  ft7, ft2, rdn  # rv32f
    RoundTrip LE                    5a0123d3  fsqrt.d  ft7, ft2, rdn  # rv32d

Assemble And Disassemble RV32C
    RoundTrip LE                    3fed  jal  -6  2  # rv32c

Assemble And Disassemble RV64IMAC
    RoundTrip LE                    000a3a83  ld  s5, 0(s4)  # rv64i
    RoundTrip LE                    abcd8a9b  addiw  s5, s11, -1348  # rv64i
    RoundTrip LE                    02ab7c3b  remuw  s8, s6, a0  # rv64m
    RoundTrip LE                    e705b52f  amomaxu.d.aqrl  a0, a6, (a1)  # rv64a
    RoundTrip LE                    eabc  sd  a5, 80(a3)  2  # rv64c

Assemble And Disassemble RV64FD
    RoundTrip LE                    d0312353  fcvt.s.lu  ft6, sp, rdn  # rv64f
    RoundTrip LE                    d2312353  fcvt.d.lu  ft6, sp, rdn  # rv64d

Assemble And Disassemble RVV
    RoundTrip LE                    00057757  vsetvli  a4, a0, e8, m1, tu, mu  # rv64v
    RoundTrip LE                    03058407  vle8ff.v  v8, (a1)  # rv64v
    RoundTrip LE                    4218a757  vfirst.m  a4, v1  # rv64v

*** Test Cases ***
# Keywords to disassemble single instruction
#
# DisasTest (BE|LE|Thumb)  HEX_CODE  [MNEMONIC]  [OPERANDS]  [CODE_SIZE=4]  [HEX_ADDR=00000000]
#  HEX_CODE  the opcode to disassemble; don't prefix with "0x"
#  MNEMONIC, OPERANDS  expected disassembly results; expect empty result if both are empty
#  CODE_SIZE  in bytes; max 8B instructions are supported
#  HEX_ADDR  hex address of the instruction, verified with the disassembler output but not influencing the opcode itself; don't prefix with "0x"

Should Assemble And Disassemble ARM Cortex-A
    [Tags]                          basic-tests
    Create Machine                  ARMv7A  arm926

    RoundTrip LE                    32855001  addlo  r5, r5, \#1  hex_addr=8000
    RoundTrip LE                    e1b00a00  lsls  r0, r0, \#20  hex_addr=813c
    RoundTrip LE                    1a00000a  bne  \#40

Should Assemble And Disassemble ARM Cortex-A53
    Create Machine                  ARMv8A  cortex-a53

    RoundTrip LE                    5400f041  b.ne  \#7688
    RoundTrip LE                    aa0603e1  mov  x1, x6
    RoundTrip LE                    aa2c1c65  orn  x5, x3, x12, lsl \#7

Should Assemble And Disassemble ARM Cortex-M
    Create Machine                  CortexM  cortex-m4

    RoundTrip Thumb                 f0230403  bic  r4, r3, \#3  hex_addr=2
    RoundTrip Thumb                 58c8  ldr  r0, [r1, r3]  2
    RoundTrip Thumb                 f44f426d  mov.w  r2, \#60672  hex_addr=9e8
    RoundTrip Thumb                 10b6  asrs  r6, r6, \#2  2  ad88

Should Assemble And Disassemble ARM Cortex-R52
    Create Machine                  ARMv8R  cortex-r52

    RoundTrip LE                    e320f000  nop
    RoundTrip LE                    43855040  orrmi  r5, r5, #64
    RoundTrip LE                    e6ff3072  uxth  r3, r2
    RoundTrip Thumb                 eb750903  sbcs.w  r9, r5, r3
    RoundTrip Thumb                 ebb272e1  subs.w  r2, r2, r1, asr #31
    RoundTrip Thumb                 fb821002  smull  r1, r0, r2, r2

Should Assemble And Disassemble RISCV32IMA
    [Tags]                          basic-tests
    Create Machine                  RiscV32  rv32ima
    Assemble And Disassemble RV32IMA

Should Assemble And Disassemble RISCV32IMAC
    Create Machine                  RiscV32  rv32imac
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32C

Should Assemble And Disassemble RISCV32IMAFDC
    Create Machine                  RiscV32  rv32imafdc
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32FD
    Assemble And Disassemble RV32C

Should Assemble And Disassemble RISCV32GC
    Create Machine                  RiscV32  rv32gc
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32FD
    Assemble And Disassemble RV32C

Should Assemble And Disassemble RISCV32GC_XANDES
    Create Machine                  RiscV32  rv32gc_xandes
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32FD
    Assemble And Disassemble RV32C

Should Assemble And Disassemble RISCV32GV
    Create Machine                  RiscV32  rv32gv
    Assemble And Disassemble RV32IMA
    Assemble And Disassemble RVV

Should Assemble And Disassemble RISCV64IMAC
    Create Machine                  RiscV64  rv64imac
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV64IMAC

Should Assemble And Disassemble RISCV64IMAFDC
    Create Machine                  RiscV64  rv64imafdc
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32FD
    Assemble And Disassemble RV64IMAC
    Assemble And Disassemble RV64FD

Should Assemble And Disassemble RISCV64GC
    Create Machine                  RiscV64  rv64gc
    Assemble And Disassemble RV32IMA  compressed=True
    Assemble And Disassemble RV32FD
    Assemble And Disassemble RV64IMAC
    Assemble And Disassemble RV64FD

Should Assemble And Disassemble RISCV64GCV
    Create Machine                  RiscV64  rv64gcv
    Assemble And Disassemble RV64IMAC
    Assemble And Disassemble RVV

Should Assemble And Disassemble PPC
    [Tags]                          basic-tests
    Create Machine                  PowerPc  e200z6

    RoundTrip LE                    4800007c  b  .+124
    RoundTrip LE                    7f880040  cmplw  7, 8, 0  hex_addr=123
    RoundTrip LE                    7ce40034  cntlzw  4, 7

Should Assemble And Disassemble PPC64 LE
    [Tags]                          basic-tests
    Create Machine                  PowerPc64  620

    # RoundTrip BE is used because of the output formatting in DisasTest BE
    # CPU is set as LE in Renode and LLVM's LE version of ppc64 is used
    RoundTrip BE                    18002389  lbz  9, 24(3)
    RoundTrip BE                    40202a7c  cmpld  10, 4
    RoundTrip BE                    71790248  bl  .+162160

Should Assemble And Disassemble Sparc
    [Tags]                          basic-tests
    Create Machine                  Sparc  leon3

    RoundTrip LE                    85e8a018  restore  %g2, 24, %g2  hex_addr=abc
    RoundTrip LE                    01000000  nop  hex_addr=abc
    RoundTrip LE                    10680047  ba  %xcc, 71

Should Assemble And Disassemble X86 Using Intel Syntax
    [Tags]                          basic-tests
    Create Machine                  X86  x86

    RoundTrip BE                    6b7b0c14  imul  edi, dword ptr [ebx + 12], 20  flags=1  reverse=False
    RoundTrip BE                    45  inc  ebp  1  flags=1  reverse=False
    RoundTrip BE                    0fb7c0  movzx  eax, ax  3  cc  flags=1  reverse=False
    RoundTrip BE                    66890cc516a9fd00  mov  word ptr [8*eax + 16623894], cx  8  a  flags=1  reverse=False
    RoundTrip BE                    0f011d5e00fc00  lidtd  [16515166]  7  abd  flags=1  reverse=False

Should Assemble And Disassemble X86 Using GAS Syntax
    [Tags]                          basic-tests
    Create Machine                  X86  x86

    RoundTrip BE                    6b7b0c14  imull  $20, 12(%ebx), %edi  reverse=False
    RoundTrip BE                    45  incl  %ebp  1  reverse=False
    RoundTrip BE                    0fb7c0  movzwl  %ax, %eax  3  cc  reverse=False
    RoundTrip BE                    66890cc516a9fd00  movw  %cx, 16623894(,%eax,8)  8  a  reverse=False
    RoundTrip BE                    0f011d5e00fc00  lidtl  16515166  7  abd  reverse=False

Should Assemble And Disassemble X86_64 Using Intel Syntax
    [Tags]                          basic-tests
    Create Machine                  X86_64  x86_64

    RoundTrip BE                    676b7b0c14  imul  edi, dword ptr [ebx + 12], 20  5  flags=1  reverse=False
    # Only testing assembly here as the disassembly-testing keywords can handle at most 8 bytes of code.
    AsTest                          48b8f0debc8a67452301  movabs  rax, 81985529234382576  flags=1
    RoundTrip BE                    48890cc516a9fd00  mov  qword ptr [8*rax + 16623894], rcx  8  flags=1  reverse=False
    RoundTrip BE                    48ffc0  inc  rax  3  flags=1  reverse=False
    RoundTrip BE                    65488b06  mov  rax, qword ptr gs:[rsi]  flags=1  reverse=False

Should Assemble And Disassemble X86_64 Using GAS Syntax
    [Tags]                          basic-tests
    Create Machine                  X86_64  x86_64

    RoundTrip BE                    676b7b0c14  imull  $20, 12(%ebx), %edi  5  reverse=False
    AsTest                          48b8f0debc8a67452301  movabsq  $81985529234382576, %rax
    RoundTrip BE                    48890cc516a9fd00  movq  %rcx, 16623894(,%rax,8)  8  reverse=False
    RoundTrip BE                    48ffc0  incq  %rax  3  reverse=False
    RoundTrip BE                    65488b06  movq  %gs:(%rsi), %rax  reverse=False

Should Assemble And Disassemble Xtensa
    Create Machine                  Xtensa  sample_controller

    RoundTrip BE                    802160  abs  a2, a8  3  reverse=False
    RoundTrip BE                    301280  add  a1, a2, a3  3  reverse=False
    RoundTrip BE                    f02000  nop  ${EMPTY}  3  reverse=False
    RoundTrip BE                    27811b  bany  a1, a2, . +31  3  reverse=False
    RoundTrip BE                    c60600  j  . +31  3  reverse=False
    RoundTrip BE                    050000  call0  . +4  3  reverse=False
    # Test Xtensa 'dense' option
    RoundTrip BE                    1812  l32i.n  a1, a2, 4  2  reverse=False
    RoundTrip BE                    1922  s32i.n  a1, a2, 8  2  reverse=False
    RoundTrip BE                    0df0  ret.n  ${EMPTY}  2  reverse=False
    RoundTrip BE                    0df0  ret.n  ${EMPTY}  2  reverse=False

Should Assemble And Execute Xtensa
    Create Machine                  Xtensa  sample_controller

    Execute Instruction             movi.n a1, 0x10
    Xtensa Register Should Be Equal  A1  0x10

    ${A1}=                          Set Variable  0x1234
    ${A2}=                          Set Variable  0x5432
    Execute Command                 cpu SetRegister 'A1' ${A1}
    Execute Command                 cpu SetRegister 'A2' ${A2}
    Execute Instruction             add a3, a1, a2
    Xtensa Register Should Be Equal  A3  0x6666

    ${arbitrary_jump_target}=       Set Variable  0x10
    Execute Command                 cpu SetRegister 'A1' ${arbitrary_jump_target}
    Execute Instruction             jx a1
    PC Should be Equal              ${arbitrary_jump_target}

    ${some_value}=                  Set Variable  0x11223344
    Execute Command                 cpu SetRegister 'A1' 0x100
    Execute Command                 sysbus WriteDoubleWord 0x100 ${some_value}
    Execute Instruction             l32i.n a2, a1, 0
    Xtensa Register Should Be Equal  A2  ${some_value}

    ${some_value}=                  Set Variable  0x88112233
    Execute Command                 cpu SetRegister 'A0' ${some_value}
    Execute Command                 cpu SetRegister 'A1' 0x100
    Execute Instruction             s32i.n a0, a1, 0
    Memory Should Be Equal          0x100  ${some_value}

Should Handle Illegal Instruction When Disassembling
    Create Machine                  RiscV64  rv64g

    DisasTest LE                    0
    DisasTest LE                    0000

Should Handle Disassembly From Invalid Address
    Create Machine                  RiscV64  rv64g

    # test with the valid address
    DisasTest LE                    02051613  slli  a2, a0, 32  hex_addr=1234

    # check whether the output contains error if we only change the address to be outside "mem"
    Run Keyword And Expect Error    'Disassembly error detected*  DisasTest LE  02051613  slli  a2, a0, 32  hex_addr=02000000

Should Take Base Address Into Account When Assembling
    Create Machine                  X86  x86

    AsTest                          8d0534120000  a: lea  eax, [a]  address=0x1234  flags=1
    AsTest                          8d053a120000  lea  eax, [a]; a:  address=0x1234  flags=1

Should Assemble Multiline Program
    ${prog}=                        Catenate  SEPARATOR=\n
    ...                             nop
    ...                             nop

    Create Machine                  X86  x86

    Execute Command                 sysbus.cpu AssembleBlock 0 "${prog}"

    ${ins}=                         Execute Command  sysbus ReadWord 0

    Should Be Equal As Numbers      ${ins}  0x9090

Should Handle Illegal Instruction When Assembling
    Create Machine                  RiscV64  rv64g

    Run Keyword And Expect Error    *unrecognized instruction mnemonic*  AsTest  00  illegalinstruction123
    Run Keyword And Expect Error    *invalid operand*  AsTest  00  sw s123, 0(sp)
    # The V extension is not in rv64g so this is illegal as well
    Run Keyword And Expect Error    *instruction requires * 'V'*  AsTest  00  vsetvli a4, a0, e8, m1, tu, mu

Should Handle Assembler Directives
    Create Machine                  X86  x86

    AsTest                          909090909090  .rept 6; nop; .endr
