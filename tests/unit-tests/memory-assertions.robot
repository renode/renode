*** Variables ***
${initial_pc}                                   0x10

${asm_byte}                                     SEPARATOR=\n
...                                             li a4,0x20000
...                                             .L3:
...                                             li a5,0x10000
...                                             .L2:
...                                             sb a5,0(a5)
...                                             addi a5,a5,1
...                                             bne a5,a4,.L2
...                                             j .L3

${asm_word}                                     SEPARATOR=\n
...                                             li a4,0x20000
...                                             .L3:
...                                             li a5,0x10000
...                                             .L2:
...                                             sh a5,0(a5)
...                                             addi a5,a5,2
...                                             bne a5,a4,.L2
...                                             j .L3

${asm_doubleword}                               SEPARATOR=\n
...                                             li a4,0x20000
...                                             .L3:
...                                             li a5,0x10000
...                                             .L2:
...                                             sw a5,0(a5)
...                                             addi a5,a5,4
...                                             bne a5,a4,.L2
...                                             j .L3

${asm_quadword}                                 SEPARATOR=\n
...                                             li a4,0x20000
...                                             .L3:
...                                             li a5,0x10000
...                                             .L2:
...                                             sd a5,0(a5)
...                                             addi a5,a5,8
...                                             bne a5,a4,.L2
...                                             j .L3

${asm_doubleword_ind}                           SEPARATOR=\n
...                                             li a3,0
...                                             li a2,0x20000
...                                             .L3:
...                                             li a5,0x10000
...                                             .L2:
...                                             add a4,a5,a3
...                                             sw a4,0(a5)
...                                             addi a5,a5,4
...                                             bne a5,a2,.L2
...                                             addi a3,a3,1
...                                             j .L3


*** Keywords ***
Create Machine
    [Arguments]                                 ${bitness}
    Execute Command                             using sysbus
    Execute Command                             mach create "risc-v"

    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { cpuType: \\"rv${bitness}imafd_zicsr_zifencei_c_v_zba_zbb_zbc_zbs_zfh_zacas_zcb\\" }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000 }"

Load Program Byte
    Store Assembled Code                        ${initial_pc}    ${asm_byte}

Load Program Word
    Store Assembled Code                        ${initial_pc}    ${asm_word}

Load Program DoubleWord
    Store Assembled Code                        ${initial_pc}    ${asm_doubleword}

Load Program QuadWord
    Store Assembled Code                        ${initial_pc}    ${asm_quadword}

Load Program DoubleWord Ind
    Store Assembled Code                        ${initial_pc}    ${asm_doubleword_ind}

Run Program
    Execute Command                             cpu PC ${initial_pc}
    # Emulation is started in the assertion as otherwise the program could race with setting watchpoints.

Create Machine 32
    Create Machine                              bitness=32

Create Machine 64
    Create Machine                              bitness=64

*** Test Cases ***
Should Read Byte At Raw Address
    Create Machine 32
    Store Byte                                  0x01    0x42
    Memory Should Be Equal                      0x01    0x42    Byte
    Memory Should Be Less Than                  0x01    0x50    Byte
    Memory Should Be Less Or Equal              0x01    0x50    Byte
    Memory Should Be Less Or Equal              0x01    0x42    Byte
    Memory Should Be Greater Than               0x01    0x40    Byte
    Memory Should Be Greater Or Equal           0x01    0x40    Byte
    Memory Should Be Greater Or Equal           0x01    0x42    Byte
    Memory Should Not Be Equal                  0x01    0xCC    Byte
    Memory Should Be Nonzero                    0x01    Byte

Should Read Word At Raw Address
    Create Machine 32
    Store Word                                  0x02    0xDEAD
    Memory Should Be Equal                      0x02    0xDEAD    Word
    Memory Should Be Less Than                  0x02    0xDFFF    Word
    Memory Should Be Less Or Equal              0x02    0xDFFF    Word
    Memory Should Be Less Or Equal              0x02    0xDEAD    Word
    Memory Should Be Greater Than               0x02    0xBEEF    Word
    Memory Should Be Greater Or Equal           0x02    0xBEEF    Word
    Memory Should Be Greater Or Equal           0x02    0xDEAD    Word
    Memory Should Not Be Equal                  0x02    0xD8FF    Word
    Memory Should Be Nonzero                    0x02    Word

Should Read Double Word At Raw Address
    Create Machine 32
    Store Double Word                           0x04    0xDEADBEEF
    Memory Should Be Equal                      0x04    0xDEADBEEF    DoubleWord
    Memory Should Be Less Than                  0x04    0xDFFF0000    DoubleWord
    Memory Should Be Less Or Equal              0x04    0xDFFF0000    DoubleWord
    Memory Should Be Less Or Equal              0x04    0xDEADBEEF    DoubleWord
    Memory Should Be Greater Than               0x04    0xBEEF0000    DoubleWord
    Memory Should Be Greater Or Equal           0x04    0xBEEF0000    DoubleWord
    Memory Should Be Greater Or Equal           0x04    0xDEADBEEF    DoubleWord
    Memory Should Not Be Equal                  0x04    0xD8FF0000    DoubleWord
    Memory Should Be Nonzero                    0x04    DoubleWord

Should Read Quad Word At Raw Address
    Create Machine 64
    Store Quad Word                             0x08    0x123456789ABCDEF0
    Memory Should Be Equal                      0x08    0x123456789ABCDEF0    QuadWord
    Memory Should Be Less Than                  0x08    0x133456789ABCDEF0    QuadWord
    Memory Should Be Less Or Equal              0x08    0x133456789ABCDEF0    QuadWord
    Memory Should Be Less Or Equal              0x08    0x123456789ABCDEF0    QuadWord
    Memory Should Be Greater Than               0x08    0x113456789ABCDEF0    QuadWord
    Memory Should Be Greater Or Equal           0x08    0x113456789ABCDEF0    QuadWord
    Memory Should Be Greater Or Equal           0x08    0x123456789ABCDEF0    QuadWord
    Memory Should Not Be Equal                  0x08    0xF0DEBC9A78563412    QuadWord
    Memory Should Be Nonzero                    0x08    QuadWord

Should Read Signed Byte At Raw Address
    Create Machine 32
    Store Byte                                  0x01    -5
    Memory Should Be Equal                      0x01    -5    Byte    signed=true
    Memory Should Be Less Than                  0x01     5    Byte    signed=true
    Memory Should Be Less Or Equal              0x01     5    Byte    signed=true
    Memory Should Be Less Or Equal              0x01    -5    Byte    signed=true
    Memory Should Be Greater Than               0x01    -8    Byte    signed=true
    Memory Should Be Greater Or Equal           0x01    -8    Byte    signed=true
    Memory Should Be Greater Or Equal           0x01    -5    Byte    signed=true
    Memory Should Not Be Equal                  0x01    -1    Byte    signed=true

Should Read Signed Word At Raw Address
    Create Machine 32
    Store Word                                  0x02    -8531
    Memory Should Be Equal                      0x02    -8531    Word    signed=true
    Memory Should Be Less Than                  0x02        0    Word    signed=true
    Memory Should Be Less Than                  0x02    -8193    Word    signed=true
    Memory Should Be Less Or Equal              0x02    -8193    Word    signed=true
    Memory Should Be Less Or Equal              0x02    -8531    Word    signed=true
    Memory Should Be Greater Than               0x02    -16657   Word    signed=true
    Memory Should Be Greater Or Equal           0x02    -16657   Word    signed=true
    Memory Should Be Greater Or Equal           0x02    -8531    Word    signed=true
    Memory Should Not Be Equal                  0x02    +8531    Word    signed=true

Should Read Signed Double Word At Raw Address
    Create Machine 32
    Store Double Word                           0x04     -500000000
    Memory Should Be Equal                      0x04     -500000000    DoubleWord    signed=true
    Memory Should Be Less Than                  0x04              0    DoubleWord    signed=true
    Memory Should Be Less Than                  0x04     -250000000    DoubleWord    signed=true
    Memory Should Be Less Or Equal              0x04     -250000000    DoubleWord    signed=true
    Memory Should Be Less Or Equal              0x04     -500000000    DoubleWord    signed=true
    Memory Should Be Greater Than               0x04    -1000000000    DoubleWord    signed=true
    Memory Should Be Greater Or Equal           0x04    -1000000000    DoubleWord    signed=true
    Memory Should Be Greater Or Equal           0x04     -500000000    DoubleWord    signed=true
    Memory Should Not Be Equal                  0x04      500000000    DoubleWord    signed=true

Should Read Signed Quad Word At Raw Address
    Create Machine 64
    Store Quad Word                             0x08    -1000000000000000000
    Memory Should Be Equal                      0x08    -1000000000000000000    QuadWord    signed=true
    Memory Should Be Less Than                  0x08                       0    QuadWord    signed=true
    Memory Should Be Less Than                  0x08     -500000000000000000    QuadWord    signed=true
    Memory Should Be Less Or Equal              0x08     -500000000000000000    QuadWord    signed=true
    Memory Should Be Less Or Equal              0x08    -1000000000000000000    QuadWord    signed=true
    Memory Should Be Greater Than               0x08    -2000000000000000000    QuadWord    signed=true
    Memory Should Be Greater Or Equal           0x08    -2000000000000000000    QuadWord    signed=true
    Memory Should Be Greater Or Equal           0x08    -1000000000000000000    QuadWord    signed=true
    Memory Should Not Be Equal                  0x08     1000000000000000000    QuadWord    signed=true

Should Read Signed Byte Of Symbol
    Create Machine 32
    Add Symbol                                  foo    0x09  1
    Store Byte                                  foo    -5
    Symbol Should Be Equal                      foo    -5    Byte    signed=true
    Symbol Should Be Less Than                  foo     5    Byte    signed=true
    Symbol Should Be Less Or Equal              foo     5    Byte    signed=true
    Symbol Should Be Less Or Equal              foo    -5    Byte    signed=true
    Symbol Should Be Greater Than               foo    -8    Byte    signed=true
    Symbol Should Be Greater Or Equal           foo    -8    Byte    signed=true
    Symbol Should Be Greater Or Equal           foo    -5    Byte    signed=true
    Symbol Should Not Be Equal                  foo    -1    Byte    signed=true

Should Read Signed Word Of Symbol
    Create Machine 32
    Add Symbol                                  bar     0x0A    2
    Store Word                                  bar    -8531
    Symbol Should Be Equal                      bar    -8531    Word    signed=true
    Symbol Should Be Less Than                  bar        0    Word    signed=true
    Symbol Should Be Less Than                  bar    -8193    Word    signed=true
    Symbol Should Be Less Or Equal              bar    -8193    Word    signed=true
    Symbol Should Be Less Or Equal              bar    -8531    Word    signed=true
    Symbol Should Be Greater Than               bar    -16657   Word    signed=true
    Symbol Should Be Greater Or Equal           bar    -16657   Word    signed=true
    Symbol Should Be Greater Or Equal           bar    -8531    Word    signed=true
    Symbol Should Not Be Equal                  bar    +8531    Word    signed=true

Should Read Signed Double Word Of Symbol
    Create Machine 32
    Add Symbol                                  baz           0x0C    4
    Store Double Word                           baz     -500000000
    Symbol Should Be Equal                      baz     -500000000    DoubleWord    signed=true
    Symbol Should Be Less Than                  baz              0    DoubleWord    signed=true
    Symbol Should Be Less Than                  baz     -250000000    DoubleWord    signed=true
    Symbol Should Be Less Or Equal              baz     -250000000    DoubleWord    signed=true
    Symbol Should Be Less Or Equal              baz     -500000000    DoubleWord    signed=true
    Symbol Should Be Greater Than               baz    -1000000000    DoubleWord    signed=true
    Symbol Should Be Greater Or Equal           baz    -1000000000    DoubleWord    signed=true
    Symbol Should Be Greater Or Equal           baz     -500000000    DoubleWord    signed=true
    Symbol Should Not Be Equal                  baz     +500000000    DoubleWord    signed=true

Should Read Signed Quad Word Of Symbol
    Create Machine 64
    Add Symbol                                  quux                    0x10    8
    Store Quad Word                             quux    -1000000000000000000
    Symbol Should Be Equal                      quux    -1000000000000000000    QuadWord    signed=true
    Symbol Should Be Less Than                  quux                       0    QuadWord    signed=true
    Symbol Should Be Less Than                  quux     -500000000000000000    QuadWord    signed=true
    Symbol Should Be Less Or Equal              quux     -500000000000000000    QuadWord    signed=true
    Symbol Should Be Less Or Equal              quux    -1000000000000000000    QuadWord    signed=true
    Symbol Should Be Greater Than               quux    -2000000000000000000    QuadWord    signed=true
    Symbol Should Be Greater Or Equal           quux    -2000000000000000000    QuadWord    signed=true
    Symbol Should Be Greater Or Equal           quux    -1000000000000000000    QuadWord    signed=true
    Symbol Should Not Be Equal                  quux    +1000000000000000000    QuadWord    signed=true

Should Read Byte Zero At Raw Address
    Create Machine 32
    Store Byte                                  0x08    0x0
    Memory Should Be Zero                       0x08    Byte

Should Read Word Zero At Raw Address
    Create Machine 32
    Store Word                                  0x08    0x0
    Memory Should Be Zero                       0x08    Word

Should Read Double Word Zero At Raw Address
    Create Machine 32
    Store Double Word                           0x08    0x0
    Memory Should Be Zero                       0x08    DoubleWord

Should Read Quad Word Zero At Raw Address
    Create Machine 64
    Store Quad Word                             0x08    0x0
    Memory Should Be Zero                       0x08    QuadWord

Should Read Byte Of Symbol
    Create Machine 32
    Add Symbol                                  foo    0x09    1
    Store Byte                                  foo    0x42
    Symbol Should Be Equal                      foo    0x42    Byte
    Symbol Should Be Equal                      foo    0x42    Byte
    Symbol Should Be Less Than                  foo    0x50    Byte
    Symbol Should Be Less Or Equal              foo    0x50    Byte
    Symbol Should Be Less Or Equal              foo    0x42    Byte
    Symbol Should Be Greater Than               foo    0x40    Byte
    Symbol Should Be Greater Or Equal           foo    0x40    Byte
    Symbol Should Be Greater Or Equal           foo    0x42    Byte
    Symbol Should Not Be Equal                  foo    0xCC    Byte
    Symbol Should Be Nonzero                    foo    Byte

Should Read Word Of Symbol
    Create Machine 32
    Add Symbol                                  bar    0x000A    2
    Store Word                                  bar    0xDEAD
    Symbol Should Be Equal                      bar    0xDEAD    Word
    Symbol Should Be Less Than                  bar    0xDFFF    Word
    Symbol Should Be Less Or Equal              bar    0xDFFF    Word
    Symbol Should Be Less Or Equal              bar    0xDEAD    Word
    Symbol Should Be Greater Than               bar    0xBEEF    Word
    Symbol Should Be Greater Or Equal           bar    0xBEEF    Word
    Symbol Should Be Greater Or Equal           bar    0xDEAD    Word
    Symbol Should Not Be Equal                  bar    0xD8FF    Word
    Symbol Should Be Nonzero                    bar    Word

Should Read Double Word Of Symbol
    Create Machine 32
    Add Symbol                                  baz    0x0000000C    4
    Store Double Word                           baz    0xDEADBEEF
    Symbol Should Be Equal                      baz    0xDEADBEEF    DoubleWord
    Symbol Should Be Equal                      baz    0xDEADBEEF    DoubleWord
    Symbol Should Be Less Than                  baz    0xDFFF0000    DoubleWord
    Symbol Should Be Less Or Equal              baz    0xDFFF0000    DoubleWord
    Symbol Should Be Less Or Equal              baz    0xDEADBEEF    DoubleWord
    Symbol Should Be Greater Than               baz    0xBEEF0000    DoubleWord
    Symbol Should Be Greater Or Equal           baz    0xBEEF0000    DoubleWord
    Symbol Should Be Greater Or Equal           baz    0xDEADBEEF    DoubleWord
    Symbol Should Not Be Equal                  baz    0xD8FF0000    DoubleWord
    Symbol Should Be Nonzero                    baz    DoubleWord

Should Read Quad Word Of Symbol
    Create Machine 64
    Add Symbol                                  quux    0x0000000000000010    8
    Store Quad Word                             quux    0x123456789ABCDEF0
    Symbol Should Be Equal                      quux    0x123456789ABCDEF0    QuadWord
    Symbol Should Be Equal                      quux    0x123456789ABCDEF0    QuadWord
    Symbol Should Be Less Than                  quux    0x133456789ABCDEF0    QuadWord
    Symbol Should Be Less Or Equal              quux    0x133456789ABCDEF0    QuadWord
    Symbol Should Be Less Or Equal              quux    0x123456789ABCDEF0    QuadWord
    Symbol Should Be Greater Than               quux    0x113456789ABCDEF0    QuadWord
    Symbol Should Be Greater Or Equal           quux    0x113456789ABCDEF0    QuadWord
    Symbol Should Be Greater Or Equal           quux    0x123456789ABCDEF0    QuadWord
    Symbol Should Not Be Equal                  quux    0xF0DEBC9A78563412    QuadWord
    Symbol Should Be Nonzero                    quux    QuadWord

Should Read Byte Of All Symbols
    Create Machine 32
    Add Symbol                                  foo    0x09    1
    Add Symbol                                  foo    0x0A    1
    Store Byte                                  foo    0x42    index=0
    Store Byte                                  foo    0x42    index=1
    All Symbols Should Be Equal                 foo    0x42    Byte
    All Symbols Should Be Less Than             foo    0x50    Byte
    All Symbols Should Be Less Or Equal         foo    0x50    Byte
    All Symbols Should Be Less Or Equal         foo    0x42    Byte
    All Symbols Should Be Greater Than          foo    0x40    Byte
    All Symbols Should Be Greater Or Equal      foo    0x40    Byte
    All Symbols Should Be Greater Or Equal      foo    0x42    Byte
    All Symbols Should Not Be Equal             foo    0xCC    Byte
    All Symbols Should Be Nonzero               foo    Byte

Should Read Word Of All Symbols
    Create Machine 32
    Add Symbol                                  bar    0x000A    2
    Add Symbol                                  bar    0x001A    2
    Store Word                                  bar    0xDEAD   index=0
    Store Word                                  bar    0xDEAD   index=1
    All Symbols Should Be Equal                 bar    0xDEAD    Word
    All Symbols Should Be Less Than             bar    0xDFFF    Word
    All Symbols Should Be Less Or Equal         bar    0xDFFF    Word
    All Symbols Should Be Less Or Equal         bar    0xDEAD    Word
    All Symbols Should Be Greater Than          bar    0xBEEF    Word
    All Symbols Should Be Greater Or Equal      bar    0xBEEF    Word
    All Symbols Should Be Greater Or Equal      bar    0xDEAD    Word
    All Symbols Should Not Be Equal             bar    0xD8FF    Word
    All Symbols Should Be Nonzero               bar    Word

Should Read Double Word Of All Symbols
    Create Machine 32
    Add Symbol                                  baz    0x0000000C    4
    Add Symbol                                  baz    0x0000001C    4
    Store Double Word                           baz    0xDEADBEEF    index=0
    Store Double Word                           baz    0xDEADBEEF    index=1
    All Symbols Should Be Equal                 baz    0xDEADBEEF    DoubleWord
    All Symbols Should Be Equal                 baz    0xDEADBEEF    DoubleWord
    All Symbols Should Be Less Than             baz    0xDFFF0000    DoubleWord
    All Symbols Should Be Less Or Equal         baz    0xDFFF0000    DoubleWord
    All Symbols Should Be Less Or Equal         baz    0xDEADBEEF    DoubleWord
    All Symbols Should Be Greater Than          baz    0xBEEF0000    DoubleWord
    All Symbols Should Be Greater Or Equal      baz    0xBEEF0000    DoubleWord
    All Symbols Should Be Greater Or Equal      baz    0xDEADBEEF    DoubleWord
    All Symbols Should Not Be Equal             baz    0xD8FF0000    DoubleWord
    All Symbols Should Be Nonzero               baz    DoubleWord

Should Read Quad Word Of All Symbols
    Create Machine 64
    Add Symbol                                  quux    0x0000000000000010    8
    Add Symbol                                  quux    0x0000000000000020    8
    Store Quad Word                             quux    0x123456789ABCDEF0    index=0
    Store Quad Word                             quux    0x123456789ABCDEF0    index=1
    All Symbols Should Be Equal                 quux    0x123456789ABCDEF0    QuadWord
    All Symbols Should Be Equal                 quux    0x123456789ABCDEF0    QuadWord
    All Symbols Should Be Less Than             quux    0x133456789ABCDEF0    QuadWord
    All Symbols Should Be Less Or Equal         quux    0x133456789ABCDEF0    QuadWord
    All Symbols Should Be Less Or Equal         quux    0x123456789ABCDEF0    QuadWord
    All Symbols Should Be Greater Than          quux    0x113456789ABCDEF0    QuadWord
    All Symbols Should Be Greater Or Equal      quux    0x113456789ABCDEF0    QuadWord
    All Symbols Should Be Greater Or Equal      quux    0x123456789ABCDEF0    QuadWord
    All Symbols Should Not Be Equal             quux    0xF0DEBC9A78563412    QuadWord
    All Symbols Should Be Nonzero               quux    QuadWord

Should Read Byte Of Any Symbol
    Create Machine 32
    Add Symbol                                  foo    0x09    1
    Add Symbol                                  foo    0x0A    1
    Store Byte                                  foo    0x42    index=0
    Store Byte                                  foo    0x84    index=1
    Any Symbol Should Be Equal                  foo    0x42    Byte
    Any Symbol Should Be Less Than              foo    0x50    Byte
    Any Symbol Should Be Less Or Equal          foo    0x50    Byte
    Any Symbol Should Be Less Or Equal          foo    0x42    Byte
    Any Symbol Should Be Greater Than           foo    0x40    Byte
    Any Symbol Should Be Greater Or Equal       foo    0x40    Byte
    Any Symbol Should Be Greater Or Equal       foo    0x42    Byte
    Any Symbol Should Not Be Equal              foo    0xCC    Byte
    Any Symbol Should Be Nonzero                foo    Byte

Should Read Word Of Any Symbol
    Create Machine 32
    Add Symbol                                  bar    0x000A    2
    Add Symbol                                  bar    0x001A    2
    Store Word                                  bar    0xDEAD    index=0
    Store Word                                  bar    0xBEEF    index=1
    Any Symbol Should Be Equal                  bar    0xDEAD    Word
    Any Symbol Should Be Less Than              bar    0xDFFF    Word
    Any Symbol Should Be Less Or Equal          bar    0xDFFF    Word
    Any Symbol Should Be Less Or Equal          bar    0xDEAD    Word
    Any Symbol Should Be Greater Than           bar    0xBEEF    Word
    Any Symbol Should Be Greater Or Equal       bar    0xBEEF    Word
    Any Symbol Should Be Greater Or Equal       bar    0xDEAD    Word
    Any Symbol Should Not Be Equal              bar    0xD8FF    Word
    Any Symbol Should Be Nonzero                bar    Word

Should Read Double Word Of Any Symbol
    Create Machine 32
    Add Symbol                                  baz    0x0000000C    4
    Add Symbol                                  baz    0x0000001C    4
    Store Double Word                           baz    0xDEADBEEF    index=0
    Store Double Word                           baz    0xDEADBEEF    index=1
    Any Symbol Should Be Equal                  baz    0xDEADBEEF    DoubleWord
    Any Symbol Should Be Equal                  baz    0xDEADBEEF    DoubleWord
    Any Symbol Should Be Less Than              baz    0xDFFF0000    DoubleWord
    Any Symbol Should Be Less Or Equal          baz    0xDFFF0000    DoubleWord
    Any Symbol Should Be Less Or Equal          baz    0xDEADBEEF    DoubleWord
    Any Symbol Should Be Greater Than           baz    0xBEEF0000    DoubleWord
    Any Symbol Should Be Greater Or Equal       baz    0xBEEF0000    DoubleWord
    Any Symbol Should Be Greater Or Equal       baz    0xDEADBEEF    DoubleWord
    Any Symbol Should Not Be Equal              baz    0xD8FF0000    DoubleWord
    Any Symbol Should Be Nonzero                baz    DoubleWord

Should Read Quad Word Of Any Symbol
    Create Machine 64
    Add Symbol                                  quux    0x0000000000000010    8
    Add Symbol                                  quux    0x0000000000000020    8
    Store Quad Word                             quux    0x123456789ABCDEF0    index=0
    Store Quad Word                             quux    0x23456789ABCDEF01    index=1
    Any Symbol Should Be Equal                  quux    0x123456789ABCDEF0    QuadWord
    Any Symbol Should Be Equal                  quux    0x123456789ABCDEF0    QuadWord
    Any Symbol Should Be Less Than              quux    0x133456789ABCDEF0    QuadWord
    Any Symbol Should Be Less Or Equal          quux    0x133456789ABCDEF0    QuadWord
    Any Symbol Should Be Less Or Equal          quux    0x123456789ABCDEF0    QuadWord
    Any Symbol Should Be Greater Than           quux    0x113456789ABCDEF0    QuadWord
    Any Symbol Should Be Greater Or Equal       quux    0x113456789ABCDEF0    QuadWord
    Any Symbol Should Be Greater Or Equal       quux    0x123456789ABCDEF0    QuadWord
    Any Symbol Should Not Be Equal              quux    0xF0DEBC9A78563412    QuadWord
    Any Symbol Should Be Nonzero                quux    QuadWord

Should Read Byte Of Symbol With Offset
    Create Machine 32
    Add Symbol                                  fooo    0x19    1
    Store Byte                                  fooo    0xCC    offset=1
    Symbol Should Be Equal                      fooo    0xCC    Byte    offset=1
    Memory Should Be Equal                      0x1A    0xCC    Byte
    Memory Should Not Be Equal                  0x19    0xCC    Byte

Should Read Word Of Symbol With Offset
    Create Machine 32
    Add Symbol                                  barr    0x001A    2
    Store Word                                  barr    0xCAFE    offset=1
    Symbol Should Be Equal                      barr    0xCAFE    Word    offset=1
    Memory Should Be Equal                      0x1C    0xCAFE    Word
    Memory Should Not Be Equal                  0x1A    0xCAFE    Word

Should Read Double Word Of Symbol With Offset
    Create Machine 32
    Add Symbol                                  bazz    0x0000001C    2
    Store DoubleWord                            bazz    0xBAAAAAAD    offset=1
    Symbol Should Be Equal                      bazz    0xBAAAAAAD    DoubleWord    offset=1
    Memory Should Be Equal                      0x20    0xBAAAAAAD    DoubleWord
    Memory Should Not Be Equal                  0x1C    0xBAAAAAAD    DoubleWord

Should Read Quad Word Of Symbol With Offset
    Create Machine 64
    Add Symbol                                  quux    0x0000000000000020    8
    Store QuadWord                              quux    0xFEE1DEAD00BAB10C    offset=1
    Symbol Should Be Equal                      quux    0xFEE1DEAD00BAB10C    QuadWord    offset=1
    Memory Should Be Equal                      0x28    0xFEE1DEAD00BAB10C    QuadWord
    Memory Should Not Be Equal                  0x20    0xFEE1DEAD00BAB10C    QuadWord

Should Read Byte Of Symbol With Negative Offset
    Create Machine 32
    Add Symbol                                  fooo    0x21    1
    Store Byte                                  fooo    0xCC    offset=-1
    Symbol Should Be Equal                      fooo    0xCC    Byte    offset=-1
    Memory Should Be Equal                      0x20    0xCC    Byte
    Memory Should Not Be Equal                  0x21    0xCC    Byte

Should Read Word Of Symbol With Negative Offset
    Create Machine 32
    Add Symbol                                  barr    0x0022    2
    Store Word                                  barr    0x4B1D    offset=-1
    Symbol Should Be Equal                      barr    0x4B1D    Word    offset=-1
    Memory Should Be Equal                      0x20    0x4B1D    Word
    Memory Should Not Be Equal                  0x22    0x4B1D    Word

Should Read Double Word Of Symbol With Negative Offset
    Create Machine 32
    Add Symbol                                  bazz    0x00000024    4
    Store DoubleWord                            bazz    0xDEAD10CC    offset=-1
    Symbol Should Be Equal                      bazz    0xDEAD10CC    DoubleWord    offset=-1
    Memory Should Be Equal                      0x20    0xDEAD10CC    DoubleWord
    Memory Should Not Be Equal                  0x24    0xDEAD10CC    DoubleWord

Should Read Quad Word Of Symbol With Negative Offset
    Create Machine 32
    Add Symbol                                  quux    0x0000000000000028    8
    Store QuadWord                              quux    0x0001ACEC09D13109    offset=-1
    Symbol Should Be Equal                      quux    0x0001ACEC09D13109    QuadWord    offset=-1
    Memory Should Be Equal                      0x20    0x0001ACEC09D13109    QuadWord
    Memory Should Not Be Equal                  0x28    0x0001ACEC09D13109    QuadWord

Should Read Byte At Raw Address After
    Create Machine  32
    Load Program Byte
    Run Program
    Memory Should Be Equal                      0x1FFF0    0xF0    Byte    timeout=3

Should Read Word At Raw Address After
    Create Machine  32
    Load Program Word
    Run Program
    Memory Should Be Equal                      0x1FFF0    0xFFF0    Word    timeout=3

Should Read Double Word At Raw Address After
    Create Machine  32
    Load Program DoubleWord
    Run Program
    Memory Should Be Equal                      0x1FFF0    0x0001FFF0    DoubleWord    timeout=3

Should Read Quad Word At Raw Address After
    Create Machine  64
    Load Program QuadWord
    Run Program
    Memory Should Be Equal                      0x1FFF0    0x000000000001FFF0    QuadWord    timeout=3

Should Read Byte Of Symbol After
    Create Machine  32
    Add Symbol                                  ffoo    0x1FFEF    1
    Load Program Byte
    Run Program
    Symbol Should Be Equal                      ffoo    0xEF    Byte    timeout=3

Should Read Word Of Symbol After
    Create Machine  32
    Add Symbol                                  baar    0x1FFEE    1
    Load Program Word
    Run Program
    Symbol Should Be Equal                      baar    0xFFEE    Word    timeout=3

Should Read Double Word Of Symbol After
    Create Machine  32
    Add Symbol                                  baaz    0x1FFEC    1
    Load Program DoubleWord
    Run Program
    Symbol Should Be Equal                      baaz    0x0001FFEC    DoubleWord    timeout=3

Should Read Quad Word Of Symbol After
    Create Machine  64
    Add Symbol                                  quxx    0x1FFE0    1
    Load Program QuadWord
    Run Program
    Symbol Should Be Equal                      quxx    0x000000000001FFE0    QuadWord    timeout=3

Should Read Byte Of All Symbols After
    Create Machine  32
    Add Symbol                                  ffoo    0x1FFEF    1
    Add Symbol                                  ffoo    0x1EFEF    1
    Load Program Byte
    Run Program
    All Symbols Should Be Equal                 ffoo    0xEF    Byte    timeout=3

Should Read Word Of All Symbols After
    Create Machine  32
    Add Symbol                                  baar    0x1FFEE    1
    Add Symbol                                  baar    0x1EEEE    1
    Load Program Word
    Run Program
    All Symbols Should Be Greater Or Equal      baar    0xEEEE    Word    timeout=3

Should Read Double Word Of All Symbols After
    Create Machine  32
    Add Symbol                                  baaz    0x1FFEC    1
    Add Symbol                                  baaz    0x1EFEC    1
    Load Program DoubleWord
    Run Program
    All Symbols Should Be Greater Or Equal      baaz    0x0001EFEC    DoubleWord    timeout=3

Should Read Quad Word Of All Symbols After
    Create Machine  64
    Add Symbol                                  quxx    0x1FFE0    1
    Add Symbol                                  quxx    0x1FFE8    1
    Load Program QuadWord
    Run Program
    All Symbols Should Be Greater Or Equal      quxx    0x000000000001FFE0    QuadWord    timeout=3

Should Read Byte Of Any Symbol After
    Create Machine  32
    Add Symbol                                  ffoo    0x1FFEF    1
    Add Symbol                                  ffoo    0x1EFEE    1
    Load Program Byte
    Run Program
    Any Symbol Should Be Equal                  ffoo    0xEF    Byte    timeout=3

Should Read Word Of Any Symbol After
    Create Machine  32
    Add Symbol                                  baar    0x1FFFE    1
    Add Symbol                                  baar    0x1EEEE    1
    Load Program Word
    Run Program
    Any Symbol Should Be Equal                  baar    0xEEEE    Word    timeout=3

Should Read Double Word Of Any Symbol After
    Create Machine  32
    Add Symbol                                  baaz    0x1FFEC    1
    Add Symbol                                  baaz    0x1EFEC    1
    Load Program DoubleWord
    Run Program
    Any Symbol Should Be Equal                  baaz    0x0001EFEC    DoubleWord    timeout=3

Should Read Quad Word Of Any Symbol After
    Create Machine  64
    Add Symbol                                  quxx    0x1FFE0    1
    Add Symbol                                  quxx    0x1FFE8    1
    Load Program QuadWord
    Run Program
    Any Symbol Should Be Equal                  quxx    0x0001FFE0    QuadWord    timeout=3

Should Read Double Word Of All Symbols Independently After
    Create Machine  32
    Add Symbol                                  baaz    0x1FFF0    4
    Add Symbol                                  baaz    0x1FFF4    4
    Add Symbol                                  baaz    0x1FFF8    4
    Load Program DoubleWord Ind
    Run Program
    All Symbols Should Independently Be Equal   baaz    0x1FFFF    DoubleWord    timeout=3

Should Not Confuse Symbol Name With Address On Store
    Create Machine  32
    Add Symbol                                  0x1234    0x1235    1
    Store Byte                                  address=0x1234    value=0x40
    Store Byte                                  symbol=0x1234    value=0x60
    Memory Should Be Equal                      0x1234    0x40    Byte
    Symbol Should Be Equal                      0x1234    0x60    Byte

Should Fail On Negative Value In Comparison Without Specifying Signed As True
    Create Machine  32
    Store Byte                                  0x01    -1
    Run Keyword And Expect Error                *Negative*
    ...                                         Memory Should Be Equal    0x01    -1

Should Fail On Negative Value In Comparison When Signed Is Explicitly False
    Create Machine  32
    Store Byte                                  0x01    -1
    Run Keyword And Expect Error                *Negative*
    ...                                         Memory Should Be Equal    0x01    -1    signed=false

Should Fail On Store To Nonexistent Symbol
    Create Machine  32
    Run Keyword And Expect Error                *Symbol * not found*
    ...                                         Store Byte    foo    0x01

Should Fail On Ambiguous Store To Symbol With Multiple Entries Without Index
    Create Machine  32
    Add Symbol                                  foo    0x01    1
    Add Symbol                                  foo    0x02    1
    TRY
        Store Byte                              foo    0x04
    EXCEPT    *Expected a single symbol*    *There are multiple symbols*    type=glob
        No Operation
    EXCEPT  AS  ${message}
        Fail    ${message}
    ELSE
        Fail    Keyword succeeded when it should fail.
    END

Should Fail On Compare Of Nonexistent Symbol
    Create Machine  32
    Run Keyword And Expect Error                *Symbol * not found*
    ...                                         Symbol Should Be Equal    foo    0x01    Byte

Should Fail On Ambiguous Compare Of Symbol With Multiple Entries Without Index
    Create Machine  32
    Add Symbol                                  foo    0x01    1
    Add Symbol                                  foo    0x02    1
    TRY
        Symbol Should Be Zero                   foo    Byte
    EXCEPT    *Expected a single symbol*    *There are multiple symbols*    type=glob
        No Operation
    EXCEPT  AS  ${message}
        Fail    ${message}
    ELSE
        Fail    Keyword succeeded when it should fail.
    END
