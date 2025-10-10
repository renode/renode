*** Settings ***
Library                             ../../tools/execution_tracer/execution_tracer_keywords.py

*** Variables ***
${bin_out_signature}                ReTrace\x04
${triple_and_model}                 riscv32 rv32imacv
${64_triple_and_model}              riscv64 rv64imacv

${riscv_amoadd_d}                   amoadd.d.aqrl a5, a4, (a3)
${riscv_amoadd_d_address}           0x2010
${riscv_amoadd_d_memory_before}     0xF00D
${64_bit_value_1}                   0xD00D1337BABEBEEF
${64_bit_value_2}                   0xFEE1FACED0D0CACA
${riscv_amoadd_d_expected_sum}      0xFEE1FACED0D1BAD7  # Can't calculate it due to not being able to call keywords here
${riscv_amoadd_d_operands_before}   SEPARATOR=${SPACE}
...                                 AMO operands before - RD: ${64_bit_value_1},
...                                 RS1: ${riscv_amoadd_d_address}
...                                 (memory value: ${riscv_amoadd_d_memory_before}),
...                                 RS2: ${64_bit_value_2}
${riscv_amoadd_d_operands_after}    SEPARATOR=${SPACE}
...                                 AMO operands after - RD: ${riscv_amoadd_d_memory_before},
...                                 RS1: ${riscv_amoadd_d_address}
...                                 (memory value: ${riscv_amoadd_d_expected_sum}),
...                                 RS2: ${64_bit_value_2}

*** Keywords ***
Create Machine Versatile
    Execute Command                             using sysbus
    Execute Command                             include @scripts/single-node/versatile.resc

    Execute Command                             cpu PerformanceInMips 1
    # the value of quantum is selected here to generate several blocks
    # of multiple instructions to check if the execution tracer can
    # disassemble blocks correctly
    Execute Command                             emulation SetGlobalQuantum "0.000004"

Create Machine RISC-V 64-bit
    [Arguments]                                 ${pc_hex}  ${memory_per_cpu}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imacv\\"; timeProvider: empty }"
    IF  ${memory_per_cpu}
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus new Bus.BusPointRegistration { address: ${pc_hex}; cpu: cpu } { size: 0x40000 }"
    ELSE
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus ${pc_hex} { size: 0x40000 }"
    END

    Execute Command                             sysbus.cpu PC ${pc_hex}

Create Machine RISC-V 32-bit
    [Arguments]                                 ${pc_hex}  ${memory_per_cpu}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imacv\\"; timeProvider: empty }"
    IF  ${memory_per_cpu}
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus new Bus.BusPointRegistration { address: ${pc_hex}; cpu: cpu } { size: 0x40000 }"
    ELSE
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus ${pc_hex} { size: 0x40000 }"
    END

Trace The Execution On The Versatile Platform
    [Arguments]                                 ${trace_format}
    Create Machine Versatile
    ${trace_file}=                              Allocate Temporary File
    Execute Command                             cpu CreateExecutionTracing "tracer" @${trace_file} ${trace_format}
    # exactly the amount of virtual time to execute 16 instructions
    Execute Command                             emulation RunFor "0.000016"
    Execute Command                             cpu DisableExecutionTracing

    ${output}=                                  Get File  ${trace_file}
    ${output_lines}=                            Split To Lines  ${output}
    RETURN  ${output_lines}

Run And Trace Simple Program On RISC-V
    [Arguments]                                 ${pc_start_hex}  ${trace_format}  ${is_binary}
    ${trace_file}=                              Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_file}" ${trace_format} ${is_binary}

    ${pc}=                                      Convert To Integer  ${pc_start_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x00000013 cpu  # nop
    Execute Command                             sysbus WriteWord ${pc+4} 0x0001 cpu            # nop
    Execute Command                             sysbus WriteDoubleWord ${pc+6} 0x00310093 cpu  # addi x1, x2, 003

    Execute Command                             sysbus.cpu Step 3
    Execute Command                             sysbus.cpu DisableExecutionTracing
    
    IF  ${is_binary}
        ${output}=                                  Get Binary File  ${trace_file}
        RETURN  ${output}
    ELSE
        ${output}=                                  Get File  ${trace_file}
        ${output_lines}=                            Split To Lines  ${output}
        RETURN  ${output_lines}
    END

Run RISC-V Program With Vcfg Instruction
    [Arguments]                                 ${pc_hex}
    Execute Command                             sysbus.cpu MSTATUS 0x600
    ${pc}=                                      Convert To Integer  ${pc_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x00000013  # nop
    Execute Command                             sysbus WriteWord ${pc+4} 0x0001            # nop
    Execute Command                             sysbus WriteDoubleWord ${pc+6} 0x04007057  # vsetvli zero, zero, e8, m1, ta, mu

    Execute Command                             sysbus.cpu Step 3

Run RISC-V Program With Amoadd Instruction
    [Arguments]                     ${pc}
    Execute Command                 sysbus.cpu PC ${pc}
    Execute Command                 sysbus.cpu SetRegister "A5" ${64_bit_value_1}
    Execute Command                 sysbus.cpu SetRegister "A4" ${64_bit_value_2}
    Execute Command                 sysbus.cpu SetRegister "A3" ${riscv_amoadd_d_address}
    Execute Command                 sysbus WriteDoubleWord ${riscv_amoadd_d_address} ${riscv_amoadd_d_memory_before} cpu
    Execute Command                 sysbus.cpu AssembleBlock ${pc} "amoadd.d.aqrl a5, a4, (a3)"

    Execute Command                 sysbus.cpu Step 1

Run RISC-V Program With Memory Access
    [Arguments]                                 ${pc_hex}
    ${pc}=                                      Convert To Integer  ${pc_hex}
    Execute Command                             sysbus.cpu PC ${pc}
    Execute Command                             sysbus WriteDoubleWord ${pc+0} 0x305B7 cpu   # lui a1, 48
    Execute Command                             sysbus WriteWord ${pc+4} 0xe537 cpu          # lui a0, 14
    Execute Command                             sysbus WriteDoubleWord ${pc+8} 0xb52023 cpu  # sw a1, 0(a0)

    Execute Command                             sysbus.cpu Step 3

Should Be Equal As Bytes
    [Arguments]                                 ${bytes}  ${str}
    ${str_bytes}                                Convert To Bytes  ${str}
    Should Be Equal                             ${bytes}  ${str_bytes}  formatter=repr

Should Dump 64-bit PCs On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 64-bit                0x2000000000  ${memory_per_cpu}

    ${pcs}=                                     Run And Trace Simple Program On RISC-V  0x2000000000  PC  False
    Should Contain                              ${pcs}[0]  0x2000000000
    Should Contain                              ${pcs}[1]  0x2000000004
    Should Contain                              ${pcs}[2]  0x2000000006

Should Dump Disassembly On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  Disassembly  False
    Should Contain                              ${trace}[0]  nop
    Should Contain                              ${trace}[1]  nop
    Should Contain                              ${trace}[2]  addi

Should Be Able To Add Memory Accesses To The Trace On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

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

Should Be Able To Add Memory Accesses To The Trace In Binary Format On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" PCAndOpcode True
    Execute Command                             tracer TrackMemoryAccesses
    Run RISC-V Program With Memory Access       0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get Binary File  ${trace_filepath}
    Length Should Be                            ${output_file}  85
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
                                                # [0]: access_type; [1-9]: access_address
    Should Be Equal As Bytes                    ${output_file}[59:69]  \x03\x00\xe0\x00\x00\x00\x00\x00\x00\x00
                                                # [0-7]: access_value
    Should Be Equal As Bytes                    ${output_file}[69:77]  \x00\x03\x00\x00\x00\x00\x00\x00
                                                # [0-7]: physical_access_address
    Should Be Equal As Bytes                    ${output_file}[77:85]  \xe0\x00\x00\x00\x00\x00\x00\x00

Should Dump 64-bit PCs As Binary On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 64-bit                0x2000000000  ${memory_per_cpu}

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000000000  PC  True
    Length Should Be                            ${trace}  37
    Should Be Equal As Bytes                    ${trace}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${trace}[08:10]  \x08\x00
 
    Should Be Equal As Bytes                    ${trace}[10:19]  \x00\x00\x00\x00\x20\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[19:28]  \x04\x00\x00\x00\x20\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[28:37]  \x06\x00\x00\x00\x20\x00\x00\x00\x00

Should Dump 32-bit PCs As Binary On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  PC  True
    Length Should Be                            ${trace}  25
    Should Be Equal As Bytes                    ${trace}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${trace}[08:10]  \x04\x00

    Should Be Equal As Bytes                    ${trace}[10:15]  \x00\x20\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[15:20]  \x04\x20\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[20:25]  \x06\x20\x00\x00\x00

Should Dump Opcodes As Binary On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  Opcode  True
    Length Should Be                            ${trace}  45
    Should Be Equal As Bytes                    ${trace}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${trace}[08:10]  \x00\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${trace}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${trace}[12:29]  ${triple_and_model}

    Should Be Equal As Bytes                    ${trace}[29:35]  \x04\x13\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[35:39]  \x02\x01\x00\x00
    Should Be Equal As Bytes                    ${trace}[39:45]  \x04\x93\x00\x31\x00\x00

Should Dump PCs And Opcodes As Binary On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x2000  ${memory_per_cpu}

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  PCAndOpcode  True
    Length Should Be                            ${trace}  57
    Should Be Equal As Bytes                    ${trace}[00:08]  ${bin_out_signature}
    Should Be Equal As Bytes                    ${trace}[08:10]  \x04\x01
                                                # [0]: uses_thumb_flag; [1]: triple_and_model_length;
    Should Be Equal As Bytes                    ${trace}[10:12]  \x00\x11 
    Should Be Equal As Bytes                    ${trace}[12:29]  ${triple_and_model}

    Should Be Equal As Bytes                    ${trace}[29:33]  \x00\x20\x00\x00
    Should Be Equal As Bytes                    ${trace}[33:39]  \x04\x13\x00\x00\x00\x00
    Should Be Equal As Bytes                    ${trace}[39:43]  \x04\x20\x00\x00
    Should Be Equal As Bytes                    ${trace}[43:47]  \x02\x01\x00\x00
    Should Be Equal As Bytes                    ${trace}[47:51]  \x06\x20\x00\x00
    Should Be Equal As Bytes                    ${trace}[51:57]  \x04\x93\x00\x31\x00\x00

Should Trace Consecutive Blocks On RISC-V
    [Arguments]                                 ${memory_per_cpu}
    Create Machine RISC-V 32-bit                0x0  ${memory_per_cpu}
    Execute Command                             sysbus.cpu ExecutionMode Continuous

    # "li x1, 0"
    Execute Command                             sysbus WriteDoubleWord 0x200 0x93 cpu
    # "li x2, 10"
    Execute Command                             sysbus WriteDoubleWord 0x204 0x00a00113 cpu
    # "addi x1, x1, 1"
    Execute Command                             sysbus WriteDoubleWord 0x208 0x00108093 cpu
    # "bne x1, x2, 0x214"
    Execute Command                             sysbus WriteDoubleWord 0x20C 0x00209463 cpu
    # "j 0x300"
    Execute Command                             sysbus WriteDoubleWord 0x210 0x0f00006f cpu

    # "c.nop"s (compressed)
    Execute Command                             sysbus WriteDoubleWord 0x214 0x01 cpu
    Execute Command                             sysbus WriteDoubleWord 0x216 0x01 cpu

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x218 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x21C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x220 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x224 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x228 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x22C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x230 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x234 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x238 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x23C 0x13 cpu

    # "j +4" - just to break the block
    # this is to test the block chaining mechanism
    Execute Command                             sysbus WriteDoubleWord 0x240 0x0040006f cpu

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x244 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x248 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x24C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x250 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x254 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x258 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x25C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x260 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x264 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x268 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x26C 0x13 cpu

    # "j +4" - just to break the block
    Execute Command                             sysbus WriteDoubleWord 0x270 0x0040006f cpu

    # "nop"s
    Execute Command                             sysbus WriteDoubleWord 0x274 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x278 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x27C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x280 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x284 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x288 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x28C 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x290 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x294 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x298 0x13 cpu
    Execute Command                             sysbus WriteDoubleWord 0x29C 0x13 cpu

    # "j 0x208"
    Execute Command                             sysbus WriteDoubleWord 0x2A0 0xf69ff06f cpu

    # "j 0x300"
    Execute Command                             sysbus WriteDoubleWord 0x300 0x6f cpu

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
    [Arguments]                                 ${memory_per_cpu}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    IF  ${memory_per_cpu}
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus new Bus.BusPointRegistration { address: 0x0; cpu: cpu } { size: 0x1000 }"
    ELSE
        Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    END

    # nop (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000000 0xe1a00000 cpu
    # blx 0x10 (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000004 0xfa000001 cpu
    # nop (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x00000008 0xe1a00000 cpu
    # wfi (ARM)
    Execute Command                             sysbus WriteDoubleWord 0x0000000c 0xe320f003 cpu
    # 2x nop (Thumb)
    Execute Command                             sysbus WriteDoubleWord 0x00000010 0x46c046c0 cpu
    # bx lr; nop (Thumb)
    Execute Command                             sysbus WriteDoubleWord 0x00000014 0x46c04770 cpu

    Execute Command                             sysbus.cpu PC 0x0

    ${FILE}=                                    Allocate Temporary File
    ${logFile}=                                 Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" @${FILE} PC
    Execute Command                             sysbus.cpu LogFile @${logFile}

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

    # translated block log should contain ARM and Thumb instructions
    ${x}=                                       Grep File  ${logFile}  0x00000004: * fa000001 *blx*#4
    Should Not Be Empty                         ${x}

    ${x}=                                       Grep File  ${logFile}  0x00000014: * 4770 *bx*lr
    Should Not Be Empty                         ${x}

Should Trace in ARM and Thumb State ARMv8R
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescription "${CURDIR}/../../platforms/cpus/cortex-r52.repl"
    # ARM
    # mov r0, r0
    Execute Command                             sysbus WriteDoubleWord 0x10000 0xe1a00000 cpu
    # nop
    Execute Command                             sysbus WriteDoubleWord 0x10004 0xe320f000 cpu
    # add r1, r6, r2
    Execute Command                             sysbus WriteDoubleWord 0x10008 0xe0861002 cpu
    # blx #65516
    Execute Command                             sysbus WriteDoubleWord 0x1000c 0xfa003ffb cpu
    # wfi
    Execute Command                             sysbus WriteDoubleWord 0x10010 0xe320f003 cpu

    # Thumb
    # movs r0, #0 ; mov r1, r0
    Execute Command                             sysbus WriteDoubleWord 0x20000 0x46012000 cpu
    # cmp r4, r2
    Execute Command                             sysbus WriteWord 0x20004 0x4294 cpu
    # sbcs.w r9, r5, r3
    Execute Command                             sysbus WriteDoubleWord 0x20006 0x0903eb75 cpu
    # bx lr ; nop
    Execute Command                             sysbus WriteDoubleWord 0x2000a 0x46c04770 cpu

    ${trace_file}=                              Allocate Temporary File
    Execute Command                             sysbus.cpu PC 0x10000
    Execute Command                             sysbus.cpu CreateExecutionTracing "tracer" "${trace_file}" Disassembly
    Execute Command                             emulation RunFor "0.0001"
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${content}=                                 Get File        ${trace_file}
    @{trace}=                                   Split To Lines  ${content}
    Length Should Be                            ${trace}        10
    Should Match                                ${trace[0]}     0x00010000: *e1a00000 *mov r0, r0
    Should Match                                ${trace[1]}     0x00010004: *e320f000 *nop
    Should Match                                ${trace[2]}     0x00010008: *e0861002 *add r1, r6, r2
    Should Match                                ${trace[3]}     0x0001000c: *fa003ffb *blx #65516
    Should Match                                ${trace[4]}     0x00020000: *2000 *movs r0, #0
    Should Match                                ${trace[5]}     0x00020002: *4601 *mov r1, r0
    Should Match                                ${trace[6]}     0x00020004: *4294 *cmp r4, r2
    Should Match                                ${trace[7]}     0x00020006: *eb750903 *sbcs.w r9, r5, r3
    Should Match                                ${trace[8]}     0x0002000a: *4770 *bx lr
    Should Match                                ${trace[9]}     0x00010010: *e320f003 *wfi


*** Test Cases ***
Should Dump PCs
    ${pcs}=                                     Trace The Execution On The Versatile Platform  PC

    Length Should Be                            ${pcs}      16
    Should Be Equal                             ${pcs[0]}   0x8000
    Should Be Equal                             ${pcs[1]}   0x8004
    Should Be Equal                             ${pcs[2]}   0x8008
    Should Be Equal                             ${pcs[3]}   0x359C08
    Should Be Equal                             ${pcs[14]}  0x8010
    Should Be Equal                             ${pcs[15]}  0x8014

Should Dump Opcodes
    ${opcodes}=                                 Trace The Execution On The Versatile Platform  Opcode

    Length Should Be                            ${opcodes}      16
    Should Be Equal                             ${opcodes[0]}   0xE321F0D3
    Should Be Equal                             ${opcodes[1]}   0xEE109F10
    Should Be Equal                             ${opcodes[2]}   0xEB0D46FE
    Should Be Equal                             ${opcodes[3]}   0xE28F3030
    Should Be Equal                             ${opcodes[14]}  0x0A0D470D
    Should Be Equal                             ${opcodes[15]}  0xE28F302C

Should Dump Opcodes For Isolated Memory
    Create Machine RISC-V 32-bit                0x2000  memory_per_cpu=True

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  Opcode  False
    Should Contain                              ${trace}[0]  0x00000013
    Should Contain                              ${trace}[1]  0x0001
    Should Contain                              ${trace}[2]  0x00310093

Should Dump PCs And Opcodes
    ${trace}=                                   Trace The Execution On The Versatile Platform  PCAndOpcode

    Length Should Be                            ${trace}      16
    Should Be Equal                             ${trace[0]}   0x8000: 0xE321F0D3
    Should Be Equal                             ${trace[1]}   0x8004: 0xEE109F10
    Should Be Equal                             ${trace[2]}   0x8008: 0xEB0D46FE
    Should Be Equal                             ${trace[3]}   0x359C08: 0xE28F3030
    Should Be Equal                             ${trace[14]}  0x8010: 0x0A0D470D
    Should Be Equal                             ${trace[15]}  0x8014: 0xE28F302C

Should Dump PCs And Opcodes For Isolated Memory
    Create Machine RISC-V 32-bit                0x2000  memory_per_cpu=True

    ${trace}=                                   Run And Trace Simple Program On RISC-V  0x2000  PCAndOpcode  False
    Should Contain                              ${trace}[0]  0x2000: 0x00000013
    Should Contain                              ${trace}[1]  0x2004: 0x0001
    Should Contain                              ${trace}[2]  0x2006: 0x00310093

Should Dump 64-bit PCs
    Should Dump 64-bit PCs On RISC-V            memory_per_cpu=False

Should Dump 64-bit PCs For Isolated Memory
    Should Dump 64-bit PCs On RISC-V            memory_per_cpu=True

Should Dump Disassembly
    Should Dump Disassembly On RISC-V           memory_per_cpu=False

Should Dump Disassembly For Isolated Memory
    Should Dump Disassembly On RISC-V           memory_per_cpu=True

Should Be Able To Add Accesses To The Memory To The Trace
    Should Be Able To Add Memory Accesses To The Trace On RISC-V  memory_per_cpu=False

Should Be Able To Add Accesses To The Isolated Memory To The Trace
    Should Be Able To Add Memory Accesses To The Trace On RISC-V  memory_per_cpu=True

Should Be Able To Add Accesses To The Memory To The Trace In Binary Format
    Should Be Able To Add Memory Accesses To The Trace In Binary Format On RISC-V  memory_per_cpu=False

Should Be Able To Add Accesses To The Isolated Memory To The Trace In Binary Format
    Should Be Able To Add Memory Accesses To The Trace In Binary Format On RISC-V  memory_per_cpu=True

Should Dump 64-bit PCs As Binary
    Should Dump 64-bit PCs As Binary On RISC-V  memory_per_cpu=False

Should Dump 64-bit PCs As Binary For Isolated Memory
    Should Dump 64-bit PCs As Binary On RISC-V  memory_per_cpu=True

Should Dump 32-bit PCs As Binary
    Should Dump 32-bit PCs As Binary On RISC-V  memory_per_cpu=False

Should Dump 32-bit PCs As Binary For Isolated Memory
    Should Dump 32-bit PCs As Binary On RISC-V  memory_per_cpu=True

Should Dump Opcodes As Binary
    Should Dump Opcodes As Binary On RISC-V     memory_per_cpu=False

Should Dump Opcodes As Binary For Isolated Memory
    Should Dump Opcodes As Binary On RISC-V     memory_per_cpu=True

Should Dump PCs And Opcodes As Binary
    Should Dump PCs And Opcodes As Binary On RISC-V  memory_per_cpu=False

Should Dump PCs And Opcodes As Binary For Isolated Memory
    Should Dump PCs And Opcodes As Binary On RISC-V  memory_per_cpu=True

Should Trace Consecutive Blocks
    Should Trace Consecutive Blocks On RISC-V   memory_per_cpu=False

Should Trace Consecutive Blocks For Isolated Memory
    Should Trace Consecutive Blocks On RISC-V   memory_per_cpu=True

Should Trace ARM Core
    Should Trace In ARM and Thumb State         memory_per_cpu=False

Should Trace ARM Core With Isolated Memory
    Should Trace In ARM and Thumb State         memory_per_cpu=True

Should Trace ARMv8R Core
    Should Trace in ARM and Thumb State ARMv8R
    
Should Trace The RISC-V Vector Configuration
    Create Machine RISC-V 32-bit                0x2000  memory_per_cpu=False

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
    Should Contain                              ${output_lines}[3]  Vector configured to VL: 0x0, VTYPE: 0x40

Should Be Able To Add Vector Configuration To The Trace In Binary Format
    Create Machine RISC-V 32-bit                0x2000  memory_per_cpu=False

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
    Should Be Equal As Bytes                    ${output_file}[57:74]  \x00\x00\x00\x00\x00\x00\x00\x00\x40\x00\x00\x00\x00\x00\x00\x00\x00

Should Show Error When Format Is Incorrect
    Create Machine RISC-V 32-bit                0x2000  memory_per_cpu=False

    ${trace_filepath}=                          Allocate Temporary File
    Run Keyword And Expect Error                *don't support binary output file with the*formatting*  Execute Command  sysbus.cpu CreateExecutionTracing "tracer" "${trace_filepath}" Disassembly true

Should Trace RISC-V Amo Operands
    Create Machine RISC-V 64-bit                0x2000  memory_per_cpu=False

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "trace_name" "${trace_filepath}" Disassembly
    Execute Command                             trace_name TrackRiscvAtomics
    Run RISC-V Program With Amoadd Instruction  0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    ${output_file}=                             Get File  ${trace_filepath}
    Log                                         ${output_file}
    ${output_lines}=                            Split To Lines  ${output_file}
    Length Should Be                            ${output_lines}  3
    Should Contain                              ${output_lines}[0]  ${riscv_amoadd_d} 
    Should Contain                              ${output_lines}[1]  ${riscv_amoadd_d_operands_before} 
    Should Contain                              ${output_lines}[2]  ${riscv_amoadd_d_operands_after}

Should Be Able To Add Amo Operands To The Trace In Binary Format
    Create Machine RISC-V 64-bit                0x2000  memory_per_cpu=False

    ${trace_filepath}=                          Allocate Temporary File
    Execute Command                             sysbus.cpu CreateExecutionTracing "trace_name" "${trace_filepath}" PCAndOpcode true
    Execute Command                             trace_name TrackRiscvAtomics
    Run RISC-V Program With Amoadd Instruction  0x2000
    Execute Command                             sysbus.cpu DisableExecutionTracing

    # Parse Binary Trace is from renode/tools/execution_tracer/execution_tracer_keywords.py
    ${trace_entries}=                           Parse Binary Trace   path=${trace_filepath}   disassemble=True
    Length Should Be                            ${trace_entries}  1
    ${entry}=                                   Evaluate   $trace_entries[0].split("\\n")

    Length Should Be                            ${entry}  3
    Should Contain                              ${entry}[0]  ${riscv_amoadd_d}   collapse_spaces=True
    Should Contain                              ${entry}[1]  ${riscv_amoadd_d_operands_before}
    Should Contain                              ${entry}[2]  ${riscv_amoadd_d_operands_after}

