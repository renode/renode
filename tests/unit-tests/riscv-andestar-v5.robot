*** Variables ***
${INSTRUCTION_ADDRESS}              0x2000

*** Keywords ***
Create Machine
    [Arguments]                     ${bits}=32  ${isa}=imac_xandesperf
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bits} @ sysbus { cpuType: \\"rv${bits}${isa}\\"; timeProvider: empty }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x100000 }"

Instruction Should Be Illegal
    [Arguments]                     ${assembly}
    Execute Command                 cpu SetRegister "mtvec" 0x1000
    Execute Command                 cpu AssembleBlock ${INSTRUCTION_ADDRESS} "${assembly}"
    Execute Command                 cpu ClearTranslationCache
    Execute Command                 cpu PC ${INSTRUCTION_ADDRESS}
    Execute Command                 cpu Step
    Register Should Be Equal        PC  0x1000
    Register Should Be Equal        MCAUSE  2
    Register Should Be Equal        MEPC  ${INSTRUCTION_ADDRESS}

Check Immediate Branch
    [Arguments]                     ${instruction}  ${value}  ${immediate}  ${offset}  ${expected_pc}
    Execute Command                 cpu SetRegister "a0" ${value}
    Execute Command                 cpu AssembleBlock ${INSTRUCTION_ADDRESS} "${instruction} a0, ${immediate}, ${offset}"
    Execute Command                 cpu ClearTranslationCache
    Execute Command                 cpu PC ${INSTRUCTION_ADDRESS}
    Execute Command                 cpu Step
    Register Should Be Equal        PC  ${expected_pc}
    Register Should Be Equal        a0  ${value}

Execute Instruction
    [Arguments]                     ${assembly}  ${expected_pc}=0x2004
    Execute Command                 cpu AssembleBlock ${INSTRUCTION_ADDRESS} "${assembly}"
    Execute Command                 cpu ClearTranslationCache
    Execute Command                 cpu PC ${INSTRUCTION_ADDRESS}
    Execute Command                 cpu Step
    Register Should Be Equal        PC  ${expected_pc}

Check GP Store
    [Arguments]                     ${instruction}  ${access}  ${offset}  ${address}  ${value}  ${expected}
    Execute Command                 cpu SetRegister "gp" 0x80000
    Execute Command                 cpu SetRegister "a0" ${value}
    Execute Command                 sysbus Write${access} ${address} 0
    Execute Instruction             ${instruction} a0, ${offset}
    ${actual}=                      Execute Command  sysbus Read${access} ${address}
    Should Be Equal As Integers     ${actual}  ${expected}

Check GP Load
    [Arguments]                     ${instruction}  ${access}  ${address}  ${offset}  ${value}  ${expected}
    Execute Command                 cpu SetRegister "gp" 0x80000
    Execute Command                 sysbus Write${access} ${address} ${value}
    Execute Instruction             ${instruction} a2, ${offset}
    Register Should Be Equal        a2  ${expected}

Check ADDIGP
    [Arguments]                     ${base}  ${offset}  ${expected}
    Execute Command                 cpu SetRegister "gp" ${base}
    Execute Instruction             nds.addigp a2, ${offset}
    Register Should Be Equal        a2  ${expected}

Check Bit Field
    [Arguments]                     ${instruction}  ${source}  ${msb}  ${lsb}  ${expected}
    Execute Command                 cpu SetRegister "a0" ${source}
    Execute Instruction             ${instruction} a2, a0, ${msb}, ${lsb}
    Register Should Be Equal        a2  ${expected}

Check Register Instruction
    [Arguments]                     ${instruction}  ${first}  ${second}  ${expected}  ${destination}=a2
    Execute Command                 cpu SetRegister "a0" ${first}
    Execute Command                 cpu SetRegister "a1" ${second}
    Execute Instruction             ${instruction} ${destination}, a0, a1
    Register Should Be Equal        ${destination}  ${expected}

Check CSR Bits
    [Arguments]                     ${csr}  ${mask}  ${expected}
    Execute Instruction             csrr a2, ${csr}
    ${value}=                       Execute Command  cpu GetRegister "a2"
    ${masked}=                      Evaluate  int($value, 0) & int($mask, 0)
    Should Be Equal As Integers     ${masked}  ${expected}

Set Rounding Mode
    [Arguments]                     ${rounding}=0
    Execute Command                 cpu SetRegister "FRM" ${rounding}
    Execute Command                 cpu SetRegister "FFLAGS" 0

Check Scalar BF16
    [Arguments]                     ${instruction}  ${source}  ${expected}  ${flags}  ${rounding}=0
    Execute Command                 cpu SetRegister "mstatus" 0x2000
    Execute Command                 cpu SetRegister "F1" ${source}
    Set Rounding Mode               ${rounding}
    Execute Instruction             ${instruction} f5, f1
    Register Should Be Equal        F5  ${expected}
    Register Should Be Equal        FFLAGS  ${flags}

Create Vector Machine
    [Arguments]                     ${extension}  ${bits}=32
    Create Machine                  bits=${bits}  isa=gc_v_${extension}
    Execute Command                 cpu VectorRegisterLength 128
    Execute Command                 cpu SetRegister "mstatus" 0x2200

Configure Vector
    [Arguments]                     ${width}  ${length}=1
    Execute Instruction             vsetivli t0, ${length}, e${width}, m1, tu, mu

Set Vector Register
    [Arguments]                     ${register}  ${width}  @{values}
    ${access}=                      Evaluate  {8: 'Byte', 16: 'Word', 32: 'DoubleWord', 64: 'QuadWord'}[int($width)]
    FOR  ${index}  ${value}  IN ENUMERATE  @{values}
        ${address}=                     Evaluate  0x4000 + $index * int($width) // 8
        Execute Command                 sysbus Write${access} ${address} ${value}
    END
    ${length}=                      Get Length  ${values}
    Configure Vector                ${width}  ${length}
    Execute Command                 cpu SetRegister "a0" 0x4000
    Execute Instruction             vle${width}.v ${register}, (a0)

Vector Should Contain
    [Arguments]                     ${register}  ${width}  @{expected}
    Register Should Be Equal        VSTART  0
    ${length}=                      Get Length  ${expected}
    Configure Vector                ${width}  ${length}
    Execute Command                 cpu SetRegister "a0" 0x5000
    Execute Instruction             vse${width}.v ${register}, (a0)
    ${access}=                      Evaluate  {8: 'Byte', 16: 'Word', 32: 'DoubleWord', 64: 'QuadWord'}[int($width)]
    FOR  ${index}  ${value}  IN ENUMERATE  @{expected}
        ${address}=                     Evaluate  0x5000 + $index * int($width) // 8
        ${actual}=                      Execute Command  sysbus Read${access} ${address}
        Should Be Equal As Integers     ${actual}  ${value}
    END

Check Vector Unary
    [Arguments]                     ${instruction}  ${sew}  ${source_width}  ${destination_width}  ${source}  ${expected}  ${flags}=0  ${rounding}=0
    Set Vector Register             v8  ${source_width}  ${source}
    Configure Vector                ${sew}
    Set Rounding Mode               ${rounding}
    Execute Instruction             ${instruction} v12, v8
    Register Should Be Equal        FFLAGS  ${flags}
    Vector Should Contain           v12  ${destination_width}  ${expected}

Check Int4 Byte Load
    [Arguments]                     ${instruction}  ${packed}  ${first}  ${second}  ${mask}=${EMPTY}
    Set Vector Register             v0  8  0x1
    Set Vector Register             v12  8  0xaa  0xaa
    Execute Command                 sysbus WriteByte 0x4000 ${packed}
    Execute Command                 cpu SetRegister "a0" 0x4000
    Configure Vector                8  2
    ${suffix}=                      Set Variable If  '${mask}' != ''  , ${mask}  ${EMPTY}
    Execute Instruction             ${instruction} v12, (a0)${suffix}
    Vector Should Contain           v12  8  ${first}  ${second}

Check Packed FP16
    [Arguments]                     ${instruction}  ${source}  ${scalar}  ${expected}  ${flags}  ${rounding}=0
    Set Vector Register             v8  16  ${source}
    Configure Vector                16
    Execute Command                 cpu SetRegister "F1" ${scalar}
    Set Rounding Mode               ${rounding}
    Execute Instruction             ${instruction} v12, f1, v8
    Register Should Be Equal        FFLAGS  ${flags}
    Vector Should Contain           v12  16  ${expected}

Check Dot Product
    [Arguments]                     ${instruction}  ${width}  ${first}  ${second}  ${accumulator}  ${expected}  ${mask}=${EMPTY}
    Set Vector Register             v0  8  0x1
    Set Vector Register             v8  ${width}  ${first}  ${first}
    Set Vector Register             v10  ${width}  ${second}  ${second}
    ${second_accumulator}=          Set Variable If  '${mask}' != ''  0x12345678  ${accumulator}
    Set Vector Register             v12  ${width}  ${accumulator}  ${second_accumulator}
    Configure Vector                ${width}  2
    ${suffix}=                      Set Variable If  '${mask}' != ''  , ${mask}  ${EMPTY}
    Execute Instruction             ${instruction} v12, v8, v10${suffix}
    ${second_expected}=             Set Variable If  '${mask}' != ''  0x12345678  ${expected}
    Vector Should Contain           v12  ${width}  ${expected}  ${second_expected}

Check Packed Int4 Load
    [Arguments]                     ${source}  ${length}  ${start}  @{expected}
    Set Vector Register             v12  8  0xaa  0xaa  0xaa
    Execute Command                 sysbus WriteDoubleWord 0x4000 ${source}
    Execute Command                 cpu SetRegister "a0" 0x4000
    Configure Vector                8  ${length}
    Execute Command                 cpu SetRegister "vstart" ${start}
    Execute Instruction             nds.vle4.v v12, (a0)
    Vector Should Contain           v12  8  @{expected}

Check Quad MAC
    [Arguments]                     ${function}  ${form}  ${width}  ${first}  ${second}  ${accumulator}  ${expected}  ${mask}=${EMPTY}
    ${destination_width}=           Evaluate  int($width) * 4
    Set Vector Register             v0  8  0x1
    Set Vector Register             v8  ${width}  ${first}  ${first}
    Set Vector Register             v10  ${width}  ${second}  ${second}
    ${second_accumulator}=          Set Variable If  '${mask}' != ''  0x12345678  ${accumulator}
    Set Vector Register             v12  ${destination_width}  ${accumulator}  ${second_accumulator}
    Configure Vector                ${width}  2
    ${scalar}=                      Evaluate  hex(0x12340000 | int($first, 0))
    Execute Command                 cpu SetRegister "s0" ${scalar}
    ${funct3}=                      Set Variable If  '${form}' == 'vx'  4  0
    ${funct7}=                      Evaluate  (int($function) << 1) | (0 if $mask else 1)

    # LLVM 23.1.3 lacks XAndesVQMac mnemonics. These register fields encode v12, v8/x8, v10.
    Execute Instruction             .insn r 0x57, ${funct3}, ${funct7}, a2, s0, a0
    ${second_expected}=             Set Variable If  '${mask}' != ''  0x12345678  ${expected}
    Vector Should Contain           v12  ${destination_width}  ${expected}  ${second_expected}

*** Test Cases ***
Should Execute BBC
    Create Machine
    Check Immediate Branch          nds.bbc  0xfffffffe  0  16  0x2010
    Check Immediate Branch          nds.bbc  0xffffffff  15  16  0x2004
    Check Immediate Branch          nds.bbc  0x7fffffff  31  -1024  0x1c00
    Check Immediate Branch          nds.bbc  0x00000000  15  1022  0x23fe
    Check Immediate Branch          nds.bbc  0x00000000  0  0  0x2000

Should Execute BBS
    Create Machine
    Check Immediate Branch          nds.bbs  0x00000001  0  16  0x2010
    Check Immediate Branch          nds.bbs  0xffff7fff  15  16  0x2004
    Check Immediate Branch          nds.bbs  0x80000000  31  -1024  0x1c00
    Check Immediate Branch          nds.bbs  0x00008000  15  1022  0x23fe
    Check Immediate Branch          nds.bbs  0x00000001  0  0  0x2000

Should Store Half Words With SHGP
    Create Machine
    Check GP Store                  nds.shgp  Word  0  0x80000  0x12345678  0x5678
    Check GP Store                  nds.shgp  Word  2  0x80002  0xabcdef01  0xef01
    Check GP Store                  nds.shgp  Word  -2  0x7fffe  0x8000  0x8000

Should Execute LBGP
    Create Machine
    Check GP Load                   nds.lbgp  Byte  0x80000  0  0x80  0xffffff80
    Check GP Load                   nds.lbgp  Byte  0x80000  0  0x7f  0x7f
    Check GP Load                   nds.lbgp  Byte  0x80000  0  0xff  0xffffffff

Should Execute LBUGP
    Create Machine
    Check GP Load                   nds.lbugp  Byte  0x80000  0  0x80  0x80
    Check GP Load                   nds.lbugp  Byte  0x80000  0  0xff  0xff
    Check GP Load                   nds.lbugp  Byte  0x80000  0  0x00  0x00

Should Execute LHGP
    Create Machine
    Check GP Load                   nds.lhgp  Word  0x80000  0  0x8000  0xffff8000
    Check GP Load                   nds.lhgp  Word  0x80000  0  0x7fff  0x7fff
    Check GP Load                   nds.lhgp  Word  0x80000  0  0xffff  0xffffffff

Should Execute LHUGP
    Create Machine
    Check GP Load                   nds.lhugp  Word  0x80000  0  0x8000  0x8000
    Check GP Load                   nds.lhugp  Word  0x80000  0  0xffff  0xffff
    Check GP Load                   nds.lhugp  Word  0x80000  0  0x0000  0x0000

Should Execute LWGP
    Create Machine
    Check GP Load                   nds.lwgp  DoubleWord  0x80000  0  0x80000000  0x80000000
    Check GP Load                   nds.lwgp  DoubleWord  0x80000  0  0x89abcdef  0x89abcdef
    Check GP Load                   nds.lwgp  DoubleWord  0x80000  0  0xffffffff  0xffffffff

Should Wrap ADDIGP At Thirty Two Bits
    Create Machine
    Check ADDIGP                    0xfffffff0  32  0x10
    Check ADDIGP                    0x1000  -16  0xff0
    Check ADDIGP                    0x1  -1  0x0

Should Execute BEQC
    Create Machine
    Check Immediate Branch          nds.beqc  0x0  0  16  0x2010
    Check Immediate Branch          nds.beqc  0xffffffff  127  16  0x2004
    Check Immediate Branch          nds.beqc  0x40  64  -1024  0x1c00
    Check Immediate Branch          nds.beqc  0x7f  127  1022  0x23fe

Should Execute BNEC
    Create Machine
    Check Immediate Branch          nds.bnec  0x1  0  16  0x2010
    Check Immediate Branch          nds.bnec  0x7f  127  16  0x2004
    Check Immediate Branch          nds.bnec  0xffffffff  64  -1024  0x1c00
    Check Immediate Branch          nds.bnec  0x0  127  1022  0x23fe

Should Execute BFOZ
    Create Machine
    Check Bit Field                 nds.bfoz  0x87654321  15  8  0x43
    Check Bit Field                 nds.bfoz  0xf  4  7  0xf0
    Check Bit Field                 nds.bfoz  0x1  0  5  0x20
    Check Bit Field                 nds.bfoz  0x87654321  31  0  0x87654321

Should Execute BFOS
    Create Machine
    Check Bit Field                 nds.bfos  0x87654321  31  28  0xfffffff8
    Check Bit Field                 nds.bfos  0xf  4  7  0xfffffff0
    Check Bit Field                 nds.bfos  0x1  0  5  0xffffffe0
    Check Bit Field                 nds.bfos  0x87654321  31  0  0x87654321

Should Decode SBGP Displacements
    Create Machine
    Check GP Store                  nds.sbgp  Byte  0x10002  0x90002  0x12345678  0x78
    Check GP Store                  nds.sbgp  Byte  -0x20000  0x60000  0xabcdef01  0x01
    Check GP Store                  nds.sbgp  Byte  0x1ffff  0x9ffff  0x80  0x80

Should Decode SHGP Displacements
    Create Machine
    Check GP Store                  nds.shgp  Word  0x10002  0x90002  0x12345678  0x5678
    Check GP Store                  nds.shgp  Word  -0x20000  0x60000  0xabcdef01  0xef01
    Check GP Store                  nds.shgp  Word  0x1fffe  0x9fffe  0x8000  0x8000

Should Decode SWGP Displacements
    Create Machine
    Check GP Store                  nds.swgp  DoubleWord  0x20000  0xa0000  0x12345678  0x12345678
    Check GP Store                  nds.swgp  DoubleWord  -0x40000  0x40000  0xabcdef01  0xabcdef01
    Check GP Store                  nds.swgp  DoubleWord  -4  0x7fffc  0x80000000  0x80000000

Should Decode Nineteen Bit LWGP Displacements
    Create Machine
    Check GP Load                   nds.lwgp  DoubleWord  0xa0000  0x20000  0x89abcdef  0x89abcdef
    Check GP Load                   nds.lwgp  DoubleWord  0x40000  -0x40000  0x12345678  0x12345678
    Check GP Load                   nds.lwgp  DoubleWord  0x7fffc  -4  0x80000000  0x80000000

Should Execute LEA H
    Create Machine
    Check Register Instruction      nds.lea.h  0x1000  0x3  0x1006
    Check Register Instruction      nds.lea.h  0xfffffffc  0x80000003  0x2
    Check Register Instruction      nds.lea.h  0x1  0x2  0x5  a0

Should Execute LEA W
    Create Machine
    Check Register Instruction      nds.lea.w  0x1000  0x3  0x100c
    Check Register Instruction      nds.lea.w  0xfffffffc  0x80000003  0x8
    Check Register Instruction      nds.lea.w  0x1  0x2  0x9  a0

Should Execute LEA D
    Create Machine
    Check Register Instruction      nds.lea.d  0x1000  0x3  0x1018
    Check Register Instruction      nds.lea.d  0xfffffffc  0x80000003  0x14
    Check Register Instruction      nds.lea.d  0x1  0x2  0x11  a0

Should Execute FFB
    Create Machine
    Check Register Instruction      nds.ffb  0x11221122  0xaaaaaa11  0xfffffffd
    Check Register Instruction      nds.ffb  0x11111100  0x0  0xfffffffc
    Check Register Instruction      nds.ffb  0x11223344  0xff  0x0
    Check Register Instruction      nds.ffb  0x00112233  0x0  0xffffffff

Should Execute FFZMISM
    Create Machine
    Check Register Instruction      nds.ffzmism  0x11223344  0x11223344  0x0
    Check Register Instruction      nds.ffzmism  0x11001100  0x11001100  0xfffffffc
    Check Register Instruction      nds.ffzmism  0x11223344  0x99223355  0xfffffffc
    Check Register Instruction      nds.ffzmism  0x11223344  0x99223344  0xffffffff

Should Execute FFMISM
    Create Machine
    Check Register Instruction      nds.ffmism  0x11001100  0x11001100  0x0
    Check Register Instruction      nds.ffmism  0x11223344  0x99223355  0xfffffffc
    Check Register Instruction      nds.ffmism  0x11223344  0x11220044  0xfffffffd

Should Execute FLMISM
    Create Machine
    Check Register Instruction      nds.flmism  0x11001100  0x11001100  0x0
    Check Register Instruction      nds.flmism  0x11223344  0x99223355  0xffffffff
    Check Register Instruction      nds.flmism  0x11223344  0x11220044  0xfffffffd

Should Sign Extend GP Loads On RV64
    Create Machine                  bits=64
    Check GP Load                   nds.lbgp  Byte  0x80000  0  0x80  0xffffffffffffff80
    Check GP Load                   nds.lhgp  Word  0x80000  0  0x8000  0xffffffffffff8000
    Check GP Load                   nds.lwgp  DoubleWord  0x80000  0  0x80000000  0xffffffff80000000
    Check GP Load                   nds.lbugp  Byte  0x80000  0  0xff  0xff
    Check GP Load                   nds.lhugp  Word  0x80000  0  0xffff  0xffff

Should Execute LEA B ZE On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.b.ze  0xabcdef0000000000  0x1234567880000003  0xabcdef0080000003
    Check Register Instruction      nds.lea.b.ze  0xffffffffffffffff  0xffffffff00000001  0x0
    Check Register Instruction      nds.lea.b.ze  0x1234000000000000  0xffffffff00000000  0x1234000000000000

Should Execute LEA H ZE On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.h.ze  0xabcdef0000000000  0x1234567880000003  0xabcdef0100000006
    Check Register Instruction      nds.lea.h.ze  0xffffffffffffffff  0xffffffff00000001  0x1
    Check Register Instruction      nds.lea.h.ze  0x1234000000000000  0xffffffff00000000  0x1234000000000000

Should Execute LEA W ZE On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.w.ze  0xabcdef0000000000  0x1234567880000003  0xabcdef020000000c
    Check Register Instruction      nds.lea.w.ze  0xffffffffffffffff  0xffffffff00000001  0x3
    Check Register Instruction      nds.lea.w.ze  0x1234000000000000  0xffffffff00000000  0x1234000000000000

Should Execute LEA D ZE On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.d.ze  0xabcdef0000000000  0x1234567880000003  0xabcdef0400000018
    Check Register Instruction      nds.lea.d.ze  0xffffffffffffffff  0xffffffff00000001  0x7
    Check Register Instruction      nds.lea.d.ze  0x1234000000000000  0xffffffff00000000  0x1234000000000000

Should Preserve Full Width LEA H On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.h  0xabcdef0000000000  0x80000003  0xabcdef0100000006
    Check Register Instruction      nds.lea.h  0x100000000  0x100000001  0x300000002
    Check Register Instruction      nds.lea.h  0xfffffffffffffffc  0x3  0x2

Should Preserve Full Width LEA W On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.w  0xabcdef0000000000  0x80000003  0xabcdef020000000c
    Check Register Instruction      nds.lea.w  0x100000000  0x100000001  0x500000004
    Check Register Instruction      nds.lea.w  0xfffffffffffffffc  0x3  0x8

Should Preserve Full Width LEA D On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.lea.d  0xabcdef0000000000  0x80000003  0xabcdef0400000018
    Check Register Instruction      nds.lea.d  0x100000000  0x100000001  0x900000008
    Check Register Instruction      nds.lea.d  0xfffffffffffffffc  0x3  0x14

Should Test RV64 Bits Above Thirty One
    Create Machine                  bits=64
    Check Immediate Branch          nds.bbc  0x8000000000000000  63  8  0x2004
    Check Immediate Branch          nds.bbc  0x8000000000000000  32  -8  0x1ff8
    Check Immediate Branch          nds.bbs  0x8000000000000000  63  8  0x2008
    Check Immediate Branch          nds.bbs  0x8000000000000000  32  -8  0x2004

Should Extract And Insert Full Width Bit Fields On RV64
    Create Machine                  bits=64
    Check Bit Field                 nds.bfoz  0xabcdef0123456789  63  32  0xabcdef01
    Check Bit Field                 nds.bfoz  0xabcdef0123456789  63  0  0xabcdef0123456789
    Check Bit Field                 nds.bfoz  0x1  0  63  0x8000000000000000
    Check Bit Field                 nds.bfos  0xabcdef0123456789  63  32  0xffffffffabcdef01
    Check Bit Field                 nds.bfos  0xf  32  35  0xffffffff00000000
    Check Bit Field                 nds.bfos  0xabcdef0123456789  63  0  0xabcdef0123456789

Should Search All Eight Bytes On RV64
    Create Machine                  bits=64
    Check Register Instruction      nds.ffb  0x0011223344556677  0x0  0xffffffffffffffff
    Check Register Instruction      nds.ffb  0x1122334455667700  0x0  0xfffffffffffffff8
    Check Register Instruction      nds.ffb  0x1122334455667788  0xff  0x0
    Check Register Instruction      nds.ffmism  0x1122334455667788  0x9922334455667788  0xffffffffffffffff
    Check Register Instruction      nds.flmism  0x1122334455667788  0x9922334455667799  0xffffffffffffffff
    Check Register Instruction      nds.ffzmism  0x1122334455667700  0x1122334455667700  0xfffffffffffffff8

Should Preserve Full Width Global Pointer On RV64
    Create Machine                  bits=64
    Check ADDIGP                    0x1234567880000000  0  0x1234567880000000
    Check ADDIGP                    0x1234567880000000  -16  0x123456787ffffff0
    Check ADDIGP                    0xfffffffffffffff0  32  0x10

Should Box Scalar BF16 With FLEN Thirty Two
    Create Machine                  isa=imaf_xandesbfhcvt
    Check Scalar BF16               nds.fcvt.s.bf16  0xffff3f80  0xffffffff3f800000  0
    Check Scalar BF16               nds.fcvt.s.bf16  0xfffe7f81  0xffffffff7fc00000  0
    Check Scalar BF16               nds.fcvt.bf16.s  0x3f800000  0xffffffffffff3f80  0

Should Widen Scalar BF16
    Create Machine                  isa=gc_xandesbfhcvt
    Check Scalar BF16               nds.fcvt.s.bf16  0xffffffffffff3f80  0xffffffff3f800000  0
    Check Scalar BF16               nds.fcvt.s.bf16  0xffffffffffff0001  0xffffffff00010000  0
    Check Scalar BF16               nds.fcvt.s.bf16  0xffffffffffff7f81  0xffffffff7fc00000  16

Should Narrow Scalar BF16
    Create Machine                  isa=gc_xandesbfhcvt
    Check Scalar BF16               nds.fcvt.bf16.s  0xffffffff3f808000  0xffffffffffff3f80  1
    Check Scalar BF16               nds.fcvt.bf16.s  0xffffffff3f808000  0xffffffffffff3f81  1  3
    Check Scalar BF16               nds.fcvt.bf16.s  0xffffffff7f800001  0xffffffffffff7fc0  16

Should Handle Scalar BF16 NaN Boxing And Overflow On RV64
    Create Machine                  bits=64  isa=gc_xandesbfhcvt
    Check Scalar BF16               nds.fcvt.s.bf16  0x0  0xffffffff7fc00000  0
    Check Scalar BF16               nds.fcvt.bf16.s  0xffffffff7f7fffff  0xffffffffffff7f80  5

Should Round Scalar BF16 In Every Rounding Mode
    Create Machine                  isa=gc_xandesbfhcvt
    FOR  ${rounding}  ${positive}  ${negative}  IN
    ...  0  0xffffffffffff3f80  0xffffffffffffbf80
    ...  1  0xffffffffffff3f80  0xffffffffffffbf80
    ...  2  0xffffffffffff3f80  0xffffffffffffbf81
    ...  3  0xffffffffffff3f81  0xffffffffffffbf80
    ...  4  0xffffffffffff3f81  0xffffffffffffbf81
        Check Scalar BF16               nds.fcvt.bf16.s  0xffffffff3f808000  ${positive}  1  ${rounding}
        Check Scalar BF16               nds.fcvt.bf16.s  0xffffffffbf808000  ${negative}  1  ${rounding}
    END

Should Reject Scalar BF16 With Floating Point Disabled
    Create Machine                  isa=gc_xandesbfhcvt
    Execute Command                 cpu SetRegister "mstatus" 0
    Instruction Should Be Illegal   nds.fcvt.s.bf16 f5, f1

Should Reject Reserved BF16 Rounding Modes
    Create Machine                  isa=gc_xandesbfhcvt
    Execute Command                 cpu SetRegister "mstatus" 0x2000
    Execute Command                 cpu SetRegister "F1" 0xffffffff3f800000
    FOR  ${rounding}  IN  5  6  7
        Set Rounding Mode               ${rounding}
        Instruction Should Be Illegal   nds.fcvt.bf16.s f5, f1
    END

Should Widen Vector BF16
    Create Vector Machine           xandesvbfhcvt
    Check CSR Bits                  0xfc2  0x80000000  0x80000000
    Check CSR Bits                  0xfc3  0x11  0x11
    Check CSR Bits                  0xfc7  0x30000  0x30000
    Check Vector Unary              nds.vfwcvt.s.bf16  16  16  32  0x3f80  0x3f800000
    Check Vector Unary              nds.vfwcvt.s.bf16  16  16  32  0x8000  0x80000000
    Check Vector Unary              nds.vfwcvt.s.bf16  16  16  32  0x7f81  0x7fc00000  16

Should Narrow Vector BF16
    Create Vector Machine           xandesvbfhcvt
    Check Vector Unary              nds.vfncvt.bf16.s  16  32  16  0x3f808000  0x3f80  1
    Check Vector Unary              nds.vfncvt.bf16.s  16  32  16  0x3f808000  0x3f81  1  3
    Check Vector Unary              nds.vfncvt.bf16.s  16  32  16  0x7f800001  0x7fc0  16

Should Convert Vector BF16 On RV64
    Create Vector Machine           xandesvbfhcvt  bits=64
    Check CSR Bits                  0xfc2  0x1100000000  0x1100000000
    Check CSR Bits                  0xfc7  0x30000  0x30000
    Check Vector Unary              nds.vfwcvt.s.bf16  16  16  32  0x0001  0x00010000
    Check Vector Unary              nds.vfncvt.bf16.s  16  32  16  0x00000001  0x0000  3

Should Restart Int4 Byte Loads At An Odd Element
    Create Vector Machine           xandesvsintload
    Set Vector Register             v12  8  0xaa  0xaa  0xaa  0xaa
    Execute Command                 sysbus WriteWord 0x4000 0x7f81
    Execute Command                 cpu SetRegister "a0" 0x4000
    Configure Vector                8  3
    Execute Command                 cpu SetRegister "vstart" 1
    Execute Instruction             nds.vln8.v v12, (a0)
    Vector Should Contain           v12  8  0xaa  0xf8  0xff  0xaa

Should Execute VLN8.V
    Create Vector Machine           xandesvsintload
    Check Int4 Byte Load            nds.vln8.v  0xf8  0xf8  0xff
    Check Int4 Byte Load            nds.vln8.v  0x70  0x0  0x7
    Check Int4 Byte Load            nds.vln8.v  0x91  0x1  0xf9
    Check Int4 Byte Load            nds.vln8.v  0xf8  0xf8  0xaa  v0.t

Should Execute VLNU8.V
    Create Vector Machine           xandesvsintload
    Check Int4 Byte Load            nds.vlnu8.v  0xf8  0x8  0xf
    Check Int4 Byte Load            nds.vlnu8.v  0x70  0x0  0x7
    Check Int4 Byte Load            nds.vlnu8.v  0x91  0x1  0x9
    Check Int4 Byte Load            nds.vlnu8.v  0xf8  0x8  0xaa  v0.t

Should Mask Packed FP16 Exceptions And Preserve Tail Elements
    Create Vector Machine           xandesvpackfph
    Set Vector Register             v0  8  0x2
    Set Vector Register             v8  16  0x7c01  0x4000  0x7c01
    Set Vector Register             v12  16  0x1111  0x2222  0x3333  0x4444
    Configure Vector                16  3
    Execute Command                 cpu SetRegister "F1" 0xffffffff40003c00
    Set Rounding Mode
    Execute Instruction             nds.vfpmadt.vf v12, f1, v8, v0.t
    Register Should Be Equal        FFLAGS  0
    Vector Should Contain           v12  16  0x1111  0x4500  0x3333  0x4444

Should Execute VFPMADT
    Create Vector Machine           xandesvpackfph
    Check Packed FP16               nds.vfpmadt.vf  0x4200  0xffffffff40004200  0x4880  0
    Check Packed FP16               nds.vfpmadt.vf  0x3bfe  0xffffffff3c01bc00  0x8010  0
    Check Packed FP16               nds.vfpmadt.vf  0x7bff  0xffffffff40000000  0x7c00  5

Should Preserve Packed FP16 Zero Signs
    Create Vector Machine           xandesvpackfph
    FOR  ${rounding}  ${expected}  IN  0  0x0  1  0x0  2  0x8000  3  0x0  4  0x0
        Check Packed FP16               nds.vfpmadt.vf  0x3c00  0xffffffff3c00bc00  ${expected}  0  ${rounding}
        Check Packed FP16               nds.vfpmadt.vf  0x3c00  0xffffffff80008000  0x8000  0  ${rounding}
    END

Should Execute VFPMADB
    Create Vector Machine           xandesvpackfph
    Check Packed FP16               nds.vfpmadb.vf  0x4200  0xffffffff40004200  0x4980  0
    Check Packed FP16               nds.vfpmadb.vf  0x3bfe  0xffffffffbc003c01  0x8010  0
    Check Packed FP16               nds.vfpmadb.vf  0x0000  0xffffffff00007c00  0x7e00  16

Should Execute VD4DOTS.VV
    Create Vector Machine           xandesvdot
    Check Dot Product               nds.vd4dots.vv  32  0x807f01ff  0x04030201  0xa  0xffffff88
    Check Dot Product               nds.vd4dots.vv  32  0xffffffff  0xffffffff  0xa  0xe
    Check Dot Product               nds.vd4dots.vv  64  0xffffffffffffffff  0xffffffffffffffff  0xa  0xe
    Check Dot Product               nds.vd4dots.vv  32  0x01010101  0x01010101  0xfffffffe  0x2  v0.t

Should Execute VD4DOTSU.VV
    Create Vector Machine           xandesvdot
    Check Dot Product               nds.vd4dotsu.vv  32  0x807f01ff  0x7f8001ff  0xa  0xffffff0c
    Check Dot Product               nds.vd4dotsu.vv  32  0xffffffff  0xffffffff  0xa  0xfffffc0e
    Check Dot Product               nds.vd4dotsu.vv  64  0xffffffffffffffff  0xffffffffffffffff  0xa  0xfffffffffffc000e
    Check Dot Product               nds.vd4dotsu.vv  32  0x01010101  0x01010101  0xfffffffe  0x2  v0.t

Should Execute VD4DOTU.VV
    Create Vector Machine           xandesvdot
    Check Dot Product               nds.vd4dotu.vv  32  0x807f01ff  0x04030201  0xa  0x488
    Check Dot Product               nds.vd4dotu.vv  32  0xffffffff  0xffffffff  0xa  0x3f80e
    Check Dot Product               nds.vd4dotu.vv  64  0xffffffffffffffff  0xffffffffffffffff  0xa  0x3fff8000e
    Check Dot Product               nds.vd4dotu.vv  32  0x01010101  0x01010101  0xfffffffe  0x2  v0.t

Should Convert And Extend Both Nibbles Of Packed Bytes
    Create Vector Machine           xandesvsinth
    Set Vector Register             v8  8  0x8f  0x70
    Configure Vector                16  4
    Execute Instruction             nds.vfwcvt.f.n.v v12, v8
    Vector Should Contain           v12  16  0xbc00  0xc800  0x0000  0x4700
    Configure Vector                32  4
    Execute Instruction             nds.vfwcvt.f.nu.v v12, v8
    Vector Should Contain           v12  32  0x41700000  0x41000000  0x00000000  0x40e00000
    Configure Vector                8  4
    Execute Instruction             vsext.vf2 v12, v8
    Vector Should Contain           v12  8  0xff  0xf8  0x00  0x07

Should Execute VFWCVT.F.N.V
    Create Vector Machine           xandesvsinth
    Check Vector Unary              nds.vfwcvt.f.n.v  16  8  16  0x7  0x4700
    Check Vector Unary              nds.vfwcvt.f.n.v  32  8  32  0x8  0xc1000000
    Check Vector Unary              nds.vfwcvt.f.n.v  16  8  16  0xf  0xbc00

Should Execute VFWCVT.F.NU.V
    Create Vector Machine           xandesvsinth
    Check Vector Unary              nds.vfwcvt.f.nu.v  16  8  16  0x7  0x4700
    Check Vector Unary              nds.vfwcvt.f.nu.v  32  8  32  0x8  0x41000000
    Check Vector Unary              nds.vfwcvt.f.nu.v  16  8  16  0xf  0x4b80

Should Execute VFWCVT.F.B.V
    Create Vector Machine           xandesvsinth
    Check Vector Unary              nds.vfwcvt.f.b.v  16  8  16  0x80  0xd800
    Check Vector Unary              nds.vfwcvt.f.b.v  32  8  32  0x7f  0x42fe0000
    Check Vector Unary              nds.vfwcvt.f.b.v  16  8  16  0xff  0xbc00

Should Execute VFWCVT.F.BU.V
    Create Vector Machine           xandesvsinth
    Check Vector Unary              nds.vfwcvt.f.bu.v  16  8  16  0x80  0x5800
    Check Vector Unary              nds.vfwcvt.f.bu.v  32  8  32  0x7f  0x42fe0000
    Check Vector Unary              nds.vfwcvt.f.bu.v  16  8  16  0xff  0x5bf8

Should Extend Nibbles With VZEXT.VF2
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vzext.vf2  8  8  8  0x8  0x8
    Check Vector Unary              vzext.vf2  8  8  8  0x7  0x7
    Check Vector Unary              vzext.vf2  8  8  8  0xf  0xf

Should Extend Nibbles With VSEXT.VF2
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vsext.vf2  8  8  8  0x8  0xf8
    Check Vector Unary              vsext.vf2  8  8  8  0x7  0x7
    Check Vector Unary              vsext.vf2  8  8  8  0xf  0xff

Should Extend Nibbles With VZEXT.VF4
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vzext.vf4  16  8  16  0x8  0x8
    Check Vector Unary              vzext.vf4  16  8  16  0x7  0x7
    Check Vector Unary              vzext.vf4  16  8  16  0xf  0xf

Should Extend Nibbles With VSEXT.VF4
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vsext.vf4  16  8  16  0x8  0xfff8
    Check Vector Unary              vsext.vf4  16  8  16  0x7  0x7
    Check Vector Unary              vsext.vf4  16  8  16  0xf  0xffff

Should Extend Nibbles With VZEXT.VF8
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vzext.vf8  32  8  32  0x8  0x8
    Check Vector Unary              vzext.vf8  32  8  32  0x7  0x7
    Check Vector Unary              vzext.vf8  32  8  32  0xf  0xf

Should Extend Nibbles With VSEXT.VF8
    Create Vector Machine           xandesvsinth
    Check Vector Unary              vsext.vf8  32  8  32  0x8  0xfffffff8
    Check Vector Unary              vsext.vf8  32  8  32  0x7  0x7
    Check Vector Unary              vsext.vf8  32  8  32  0xf  0xffffffff

Should Execute VLE4
    Create Vector Machine           xandesvsinth
    Check Packed Int4 Load          0x0  0  0  0xaa  0xaa  0xaa
    Check Packed Int4 Load          0x0000f870  4  0  0x70  0xf8
    Check Packed Int4 Load          0x00654321  5  3  0xaa  0x43  0x65
    Check Packed Int4 Load          0x0  2  0  0x0

Should Truncate Quad MAC Scalars On RV64
    Create Vector Machine           xandesvqmac  bits=64
    Set Vector Register             v10  8  0xff
    Set Vector Register             v12  32  0
    Configure Vector                8
    Execute Command                 cpu SetRegister "s0" 0x12345678ffffff80
    # VQMACC.VX v12, s0, v10 (section 3.10.4).
    Execute Instruction             .insn r 0x57, 4, 123, a2, s0, a0
    Vector Should Contain           v12  32  0x80

Should Advertise Quad MAC Configuration Registers
    Create Vector Machine           xandesvqmac
    Check CSR Bits                  0xfc2  0x80000000  0x80000000
    Check CSR Bits                  0xfc3  0x10100000  0x10100000
    Check CSR Bits                  0xfcb  0x8  0x8
    Reset Emulation
    Create Vector Machine           xandesvqmac  bits=64
    Check CSR Bits                  0xfc2  0x1010000000000000  0x10000000000000
    Check CSR Bits                  0xfca  0x800000000  0x800000000

Should Execute VQMACCU VV
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  60  vv  8  0x80  0xff  0xa  0x7f8a
    Check Quad MAC                  60  vv  16  0x8000  0xffff  0xa  0x7fff800a
    Check Quad MAC                  60  vv  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACCU VX
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  60  vx  8  0x80  0xff  0xa  0x7f8a
    Check Quad MAC                  60  vx  16  0x8000  0xffff  0xa  0x7fff800a
    Check Quad MAC                  60  vx  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACC VV
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  61  vv  8  0x80  0xff  0xa  0x8a
    Check Quad MAC                  61  vv  16  0x8000  0xffff  0xa  0x800a
    Check Quad MAC                  61  vv  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACC VX
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  61  vx  8  0x80  0xff  0xa  0x8a
    Check Quad MAC                  61  vx  16  0x8000  0xffff  0xa  0x800a
    Check Quad MAC                  61  vx  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACCUS VX
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  62  vx  8  0x80  0xff  0xa  0xffffff8a
    Check Quad MAC                  62  vx  16  0x8000  0xffff  0xa  0xffffffffffff800a
    Check Quad MAC                  62  vx  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACCSU VV
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  63  vv  8  0x80  0xff  0xa  0xffff808a
    Check Quad MAC                  63  vv  16  0x8000  0xffff  0xa  0xffffffff8000800a
    Check Quad MAC                  63  vv  8  0x2  0x3  0xfffffffe  0x4  masked

Should Execute VQMACCSU VX
    Create Vector Machine           xandesvqmac
    Check Quad MAC                  63  vx  8  0x80  0xff  0xa  0xffff808a
    Check Quad MAC                  63  vx  16  0x8000  0xffff  0xa  0xffffffff8000800a
    Check Quad MAC                  63  vx  8  0x2  0x3  0xfffffffe  0x4  masked
