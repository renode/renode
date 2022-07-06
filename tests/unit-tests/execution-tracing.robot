*** Variables ***
${bin_out_signature}=                           ReTrace\x02
${triple_and_model}=                            riscv32 rv32imacv

*** Keywords ***
Create Machine
    Execute Command                             using sysbus
    Execute Command                             include @scripts/single-node/versatile.resc

    Execute Command                             cpu PerformanceInMips 1
    # the value of quantum is selected here to generate several blocks
    # of multiple instructions to check if the execution tracer can
    # disassemble blocks correctly
    Execute Command                             emulation SetGlobalQuantum "0.000004"

Create Machine RISC-V 64-bit
    [Arguments]                                 ${pc_hex}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imacv\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus ${pc_hex} { size: 0x40000 }"

    Execute Command                             sysbus.cpu ExecutionMode SingleStepBlocking
    Execute Command                             sysbus.cpu PC ${pc_hex}

Create Machine RISC-V 32-bit
    [Arguments]                                 ${pc_hex}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imacv\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus ${pc_hex} { size: 0x40000 }"

    Execute Command                             sysbus.cpu ExecutionMode SingleStepBlocking

Run Simple RISC-V Program
    [Arguments]                                 ${pc_hex}
    ${pc}=                                      Convert To Integer  ${pc_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x00000013  # nop
    Execute Command                             sysbus WriteWord ${pc+4} 0x0001            # nop
    Execute Command                             sysbus WriteDoubleWord ${pc+6} 0x00310093  # addi x1, x2, 003

    Start Emulation
    Execute Command                             sysbus.cpu Step 3

Run RISC-V Program With Vcfg Instruction
    [Arguments]                                 ${pc_hex}
    Execute Command                             sysbus.cpu MSTATUS 0x600
    ${pc}=                                      Convert To Integer  ${pc_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x00000013  # nop
    Execute Command                             sysbus WriteWord ${pc+4} 0x0001            # nop
    Execute Command                             sysbus WriteDoubleWord ${pc+6} 0x04007057  # vsetvli zero, zero, e8, m1, ta, mu

    Start Emulation
    Execute Command                             sysbus.cpu Step 3

Run RISC-V Program With Memory Access
    [Arguments]                                 ${pc_hex}
    ${pc}=                                      Convert To Integer  ${pc_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x305B7     # lui a1, 48
    Execute Command                             sysbus WriteWord ${pc+4} 0xe537            # lui a0, 14
    Execute Command                             sysbus WriteDoubleWord ${pc+8} 0xb52023    # sw a1, 0(a0)

    Start Emulation
    Execute Command                             sysbus.cpu Step 3

Should Be Equal As Bytes
    [Arguments]                                 ${bytes}  ${str}
    ${str_bytes}                                Convert To Bytes  ${str}
    Should Be Equal                             ${bytes}  ${str_bytes}  formatter=repr

*** Test Cases ***
Should Dump PCs
    Create Machine
    ${FILE}=                                    Allocate Temporary File

    Execute Command                             cpu CreateExecutionTracing "tracer" @${FILE} PC
    # exactly the amount of virtual time to execute 16 instructions
    Execute Command                             emulation RunFor "0.000016"

    Execute Command                             cpu DisableExecutionTracing

    ${content}=                                 Get File  ${FILE}
    @{pcs}=                                     Split To Lines  ${content}

    Length Should Be                            ${pcs}      16
    Should Be Equal                             ${pcs[0]}   0x8000
    Should Be Equal                             ${pcs[1]}   0x8004
    Should Be Equal                             ${pcs[2]}   0x8008
    Should Be Equal                             ${pcs[3]}   0x359C08
    Should Be Equal                             ${pcs[14]}  0x8010
    Should Be Equal                             ${pcs[15]}  0x8014

Should Dump Opcodes
    Create Machine
    ${FILE}=                                    Allocate Temporary File

    Execute Command                             cpu CreateExecutionTracing "tracer" @${FILE} Opcode
    # exactly the amount of virtual time to execute 16 instructions
    Execute Command                             emulation RunFor "0.000016"

    Execute Command                             cpu DisableExecutionTracing

    ${content}=                                 Get File  ${FILE}
    @{pcs}=                                     Split To Lines  ${content}

    Length Should Be                            ${pcs}      16
    Should Be Equal                             ${pcs[0]}   0xE321F0D3
    Should Be Equal                             ${pcs[1]}   0xEE109F10
    Should Be Equal                             ${pcs[2]}   0xEB0D46FE
    Should Be Equal                             ${pcs[3]}   0xE28F3030
    Should Be Equal                             ${pcs[14]}  0x0A0D470D
    Should Be Equal                             ${pcs[15]}  0xE28F302C

Should Dump PCs And Opcodes
    Create Machine
    ${FILE}=                                    Allocate Temporary File

    Execute Command                             cpu CreateExecutionTracing "tracer" @${FILE} PCAndOpcode
    # exactly the amount of virtual time to execute 16 instructions
    Execute Command                             emulation RunFor "0.000016"

    Execute Command                             cpu DisableExecutionTracing

    ${content}=                                 Get File  ${FILE}
    @{pcs}=                                     Split To Lines  ${content}

    Length Should Be                            ${pcs}      16
    Should Be Equal                             ${pcs[0]}   0x8000: 0xE321F0D3
    Should Be Equal                             ${pcs[1]}   0x8004: 0xEE109F10
    Should Be Equal                             ${pcs[2]}   0x8008: 0xEB0D46FE
    Should Be Equal                             ${pcs[3]}   0x359C08: 0xE28F3030
    Should Be Equal                             ${pcs[14]}  0x8010: 0x0A0D470D
    Should Be Equal                             ${pcs[15]}  0x8014: 0xE28F302C

Should Dump 64-bit PCs
    Create Machine RISC-V 64-bit                0x2000000000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" PC
    Run Simple RISC-V Program                          0x2000000000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get File  ${trace_filepath}
    ${output_lines}=                            Split To Lines  ${output_file}
    Should Contain                              ${output_lines}[0]  0x2000000000
    Should Contain                              ${output_lines}[1]  0x2000000004
    Should Contain                              ${output_lines}[2]  0x2000000006

Should Dump Disassembly
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" Disassembly
    Run Simple RISC-V Program                          0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get File  ${trace_filepath}
    ${output_lines}=                            Split To Lines  ${output_file}
    Should Contain                              ${output_lines}[0]  nop
    Should Contain                              ${output_lines}[1]  nop
    Should Contain                              ${output_lines}[2]  addi

Should Be Able To Add Memory Accesses To The Trace
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" Disassembly
    Execute Command                             tracer TrackMemoryAccesses
    Run RISC-V Program With Memory Access       0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get File  ${trace_filepath}
    ${output_lines}=                            Split To Lines  ${output_file}
    Should Contain                              ${output_lines}[0]  lui a1, 48
    Should Contain                              ${output_lines}[1]  lui a0, 14
    Should Contain                              ${output_lines}[2]  sw a1, 0(a0)
    Should Contain                              ${output_lines}[3]  MemoryWrite with address 0xE000

Should Be Able To Add Memory Accesses To The Trace In Binary Format
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" PCAndOpcode true
    Execute Command                             tracer TrackMemoryAccesses
    Run RISC-V Program With Memory Access       0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  69
    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
                                                # [0]: pc_width; [1]: include_opcode
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x04\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${output_file}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${output_file}[12:29]  ${triple_and_model}

                                                # [0:4]: pc; [4]: opcode_length; [5:9]: opcode; [10]: additional_data_type = None  
    Should Be Equal As Bytes                    ${output_file}[29:39]  \x00\x20\x00\x00\x04\xb7\x05\x03\x00\x00
    Should Be Equal As Bytes                    ${output_file}[39:49]  \x04\x20\x00\x00\x04\x37\xe5\x00\x00\x00
                                                # [0:4]: pc; [4]: opcode_length; [5:9]: opcode; [10]: additional_data_type = MemoryAccess
    Should Be Equal As Bytes                    ${output_file}[49:59]  \x08\x20\x00\x00\x04\x23\x20\xb5\x00\x01
                                                # [0]: access_type; [1-9]: access_address; [10]: additional_data_type = None
    Should Be Equal As Bytes                    ${output_file}[59:69]  \x03\x00\xe0\x00\x00\x00\x00\x00\x00\x00

Should Dump 64-bit PCs As Binary
    Create Machine RISC-V 64-bit                0x2000000000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" PC true
    Run Simple RISC-V Program                          0x2000000000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  37
    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x08\x00
 
    Should Be Equal As Bytes                    ${output_file}[10:19]  \x00\x00\x00\x00\x20\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[19:28]  \x04\x00\x00\x00\x20\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[28:37]  \x06\x00\x00\x00\x20\x00\x00\x00\x00

Should Dump 32-bit PCs As Binary
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" PC true
    Run Simple RISC-V Program                          0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  25
    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x04\x00

    Should Be Equal As Bytes                    ${output_file}[10:15]  \x00\x20\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[15:20]  \x04\x20\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[20:25]  \x06\x20\x00\x00\x00

Should Dump Opcodes As Binary
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer_name" "${trace_filepath}" Opcode true
    Run Simple RISC-V Program                          0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  45
    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x00\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${output_file}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${output_file}[12:29]  ${triple_and_model}

    Should Be Equal As Bytes                    ${output_file}[29:35]  \x04\x13\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[35:39]  \x02\x01\x00\x00
    Should Be Equal As Bytes                    ${output_file}[39:45]  \x04\x93\x00\x31\x00\x00

Should Dump PCs And Opcodes As Binary
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer_name" "${trace_filepath}" PCAndOpcode true
    Run Simple RISC-V Program                          0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  57
    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x04\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${output_file}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${output_file}[12:29]  ${triple_and_model}

    Should Be Equal As Bytes                    ${output_file}[29:33]  \x00\x20\x00\x00
    Should Be Equal As Bytes                    ${output_file}[33:39]  \x04\x13\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${output_file}[39:43]  \x04\x20\x00\x00
    Should Be Equal As Bytes                    ${output_file}[43:47]  \x02\x01\x00\x00
    Should Be Equal As Bytes                    ${output_file}[47:51]  \x06\x20\x00\x00
    Should Be Equal As Bytes                    ${output_file}[51:57]  \x04\x93\x00\x31\x00\x00

Should Show Error When Format Is Incorrect
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Run Keyword And Expect Error                *don't support binary output file with the*formatting*  Execute Command  sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" Disassembly true

Should Trace Consecutive Blocks
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32gc\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x10000 }"

    # "li x1, 0"
    Execute Command                             sysbus WriteDoubleWord 0x200 0x93
    # "li x2, 10"
    Execute Command                             sysbus WriteDoubleWord 0x204 0x00a00113
    # "addi x1, x1, 1"
    Execute Command                             sysbus WriteDoubleWord 0x208 0x00108093
    # "bne x1, x2, 0x214"
    Execute Command                             sysbus WriteDoubleWord 0x20C 0x00209463
    # "j 0x300"
    Execute Command                             sysbus WriteDoubleWord 0x210 0x0f00006f

    # "c.nop"s (compressed)
    Execute Command                             sysbus WriteDoubleWord 0x214 0x01
    Execute Command                             sysbus WriteDoubleWord 0x216 0x01

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x218 0x13
    Execute Command                             sysbus WriteDoubleWord 0x21C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x220 0x13
    Execute Command                             sysbus WriteDoubleWord 0x224 0x13
    Execute Command                             sysbus WriteDoubleWord 0x228 0x13
    Execute Command                             sysbus WriteDoubleWord 0x22C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x230 0x13
    Execute Command                             sysbus WriteDoubleWord 0x234 0x13
    Execute Command                             sysbus WriteDoubleWord 0x238 0x13
    Execute Command                             sysbus WriteDoubleWord 0x23C 0x13

    # "j +4" - just to break the block
    # this is to test the block chaining mechanism
    Execute Command                             sysbus WriteDoubleWord 0x240 0x0040006f

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x244 0x13
    Execute Command                             sysbus WriteDoubleWord 0x248 0x13
    Execute Command                             sysbus WriteDoubleWord 0x24C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x250 0x13
    Execute Command                             sysbus WriteDoubleWord 0x254 0x13
    Execute Command                             sysbus WriteDoubleWord 0x258 0x13
    Execute Command                             sysbus WriteDoubleWord 0x25C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x260 0x13
    Execute Command                             sysbus WriteDoubleWord 0x264 0x13
    Execute Command                             sysbus WriteDoubleWord 0x268 0x13
    Execute Command                             sysbus WriteDoubleWord 0x26C 0x13

    # "j +4" - just to break the block
    Execute Command                             sysbus WriteDoubleWord 0x270 0x0040006f

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x274 0x13
    Execute Command                             sysbus WriteDoubleWord 0x278 0x13
    Execute Command                             sysbus WriteDoubleWord 0x27C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x280 0x13
    Execute Command                             sysbus WriteDoubleWord 0x284 0x13
    Execute Command                             sysbus WriteDoubleWord 0x288 0x13
    Execute Command                             sysbus WriteDoubleWord 0x28C 0x13
    Execute Command                             sysbus WriteDoubleWord 0x290 0x13
    Execute Command                             sysbus WriteDoubleWord 0x294 0x13
    Execute Command                             sysbus WriteDoubleWord 0x298 0x13
    Execute Command                             sysbus WriteDoubleWord 0x29C 0x13

    # "j 0x208"
    Execute Command                             sysbus WriteDoubleWord 0x2A0 0xf69ff06f

    # "j 0x300"
    Execute Command                             sysbus WriteDoubleWord 0x300 0x6f

    Execute Command                             sysbus.cpu PC 0x200

    ${FILE}=                                    Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" @${FILE} PC

    # run for 400 instructions
    Execute Command                             sysbus.cpu PerformanceInMips 1
    Execute Command                             emulation RunFor "0.000400"

    # should reach the end of the execution
    ${pc}=                                      Execute Command  sysbus.cpu PC
    Should Contain                              ${pc}  0x300

    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${content}=                                 Get File  ${FILE}
    @{pcs}=                                     Split To Lines  ${content}

    Length Should Be                            ${pcs}      400
    Should Be Equal                             ${pcs[0]}   0x200
    Should Be Equal                             ${pcs[1]}   0x204
    Should Be Equal                             ${pcs[2]}   0x208
    Should Be Equal                             ${pcs[3]}   0x20C
    # here we skip a jump to 0x300 (it should fire at the very end)
    Should Be Equal                             ${pcs[4]}   0x214
    Should Be Equal                             ${pcs[5]}   0x216
    Should Be Equal                             ${pcs[6]}   0x218
    Should Be Equal                             ${pcs[7]}   0x21C
    # first iteration of the loop
    Should Be Equal                             ${pcs[40]}  0x2A0
    Should Be Equal                             ${pcs[41]}  0x208
    # another iteration of the loop
    Should Be Equal                             ${pcs[79]}  0x2A0
    Should Be Equal                             ${pcs[80]}  0x208
    # and another
    Should Be Equal                             ${pcs[118]}  0x2A0
    Should Be Equal                             ${pcs[119]}  0x208
    # and the last one
    Should Be Equal                             ${pcs[352]}  0x2A0
    Should Be Equal                             ${pcs[353]}  0x208
    Should Be Equal                             ${pcs[354]}  0x20C
    Should Be Equal                             ${pcs[355]}  0x210
    Should Be Equal                             ${pcs[356]}  0x300

Should Trace In ARM and Thumb State
    Execute Command                             mach create

    Execute Command                             machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.Arm @ sysbus { cpuType: \\"cortex-a9\\" }"

    # nop (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000000 0xe1a00000
    # blx 0x10 (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000004 0xfa000001
    # nop (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000008 0xe1a00000
    # wfi (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x0000000c 0xe320f003
    # 2x nop (Thumb)
    Execute Command                             sysbus WriteDoubleWord 0x00000010 0x46c046c0
    # bx lr; nop (Thumb)
    Execute Command                             sysbus WriteDoubleWord 0x00000014 0x46c04770

    Execute Command                             sysbus.cpu PC 0x0

    ${FILE}=                                    Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" @${FILE} PC

    Execute Command                             emulation RunFor "0.0001"

    # should reach the end of the execution
    PC Should Be Equal                          0x10

    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${content}=                                 Get File  ${FILE}
    @{pcs}=                                     Split To Lines  ${content}

    Length Should Be                            ${pcs}      7
    Should Be Equal                             ${pcs[0]}   0x0
    Should Be Equal                             ${pcs[1]}   0x4
    Should Be Equal                             ${pcs[2]}   0x10
    Should Be Equal                             ${pcs[3]}   0x12
    Should Be Equal                             ${pcs[4]}   0x14
    Should Be Equal                             ${pcs[5]}   0x8
    Should Be Equal                             ${pcs[6]}   0xC
    
Should trace the RISC-V Vector Configuration
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "trace_name" "${trace_filepath}" Disassembly
    Execute Command                             trace_name TrackVectorConfiguration
    Run RISC-V Program With Vcfg Instruction    0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get File  ${trace_filepath}
    Log                                         ${output_file}
    ${output_lines}=                            Split To Lines  ${output_file}
    Length Should Be                            ${output_lines}  4
    Should Contain                              ${output_lines}[0]  nop
    Should Contain                              ${output_lines}[1]  nop
    Should Contain                              ${output_lines}[2]  vsetvli zero, zero, e8, m1, ta, mu
    Should Contain                              ${output_lines}[3]  Vector configured to VL: 0x0, VTYPE: 0x0

Should Be Able To Add Vector Configuration To The Trace In Binary Format
    Create Machine RISC-V 32-bit                0x2000

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "trace_name" "${trace_filepath}" PCAndOpcode true
    Execute Command                             trace_name TrackVectorConfiguration
    Run RISC-V Program With Vcfg Instruction    0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  74

    Should Be Equal As Bytes                    ${output_file}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${output_file}[08:10]  \x04\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${output_file}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${output_file}[12:29]  ${triple_and_model}

                                                # [0:4]: pc; [4]: opcode_length; [5:9]: opcode; [10]: additional_data_type = None  
    Should Be Equal As Bytes                    ${output_file}[29:39]  \x00\x20\x00\x00\x04\x13\x00\x00\x00\x00
                                                # [0:4]: pc; [4]: opcode_length; [5:7]: opcode; [8]: additional_data_type = None  
    Should Be Equal As Bytes                    ${output_file}[39:47]  \x04\x20\x00\x00\x02\x01\x00\x00
                                                # [0:4]: pc; [4]: opcode_length; [5:9]: opcode; [10]: additional_data_type = VectorConfiguration
    Should Be Equal As Bytes                    ${output_file}[47:57]  \x06\x20\x00\x00\x04\x57\x70\x00\x04\x02
                                                # [0:8]: vl; [8:16]: vtype; [16]: additional_data_type = None
    Should Be Equal As Bytes                    ${output_file}[57:74]  \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00

