*** Variables ***
${X1}                                           1
${X2}                                           2
${X3}                                           3
# simple loop that repeatedly writes to a few addresses
${PROG_DIRTY_ADDRESS}               SEPARATOR=\n
...                                 loop:
...                                 la t1, store_target
...                                 sw t0, 0(t1)
...                                 sw t0, 4(t1)
...                                 sw t0, 8(t1)
...                                 sw t0, 12(t1)
...                                 jal loop
...                                 store_target:

${WRITER_ENTRY_PC}                              0x1000
${READER_ENTRY_PC}                              0x1100
# Set x1 to 1, then spin.
${READER_PROGRAM}                   SEPARATOR=\n
...                                 c.li x1, 1
...                                 loop: j loop
# Copy the assembled c.li x1, 2 over the reader's first instruction, then spin.
${WRITER_PROGRAM}                   SEPARATOR=\n
...                                 la t0, replacement
...                                 lhu t0, 0(t0)
...                                 li t1, ${READER_ENTRY_PC}
...                                 sh t0, 0(t1)
...                                 loop: j loop
...                                 replacement: c.li x1, 2

*** Keywords ***
Create Machine                                  
    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty; allowUnalignedAccesses: true }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x10000000 }"
  
*** Test Cases ***
Should Invalidate On Write
    Create Machine

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0x0 0x00100093
    # j .
    Execute Command                             sysbus WriteDoubleWord 0x4 0x0000006f

    Execute Command                             cpu PC 0x0
    Register Should Be Equal                    ${X1}  0x0
    Execute Command                             emulation RunFor "0.01"

    PC Should Be Equal                          0x4
    Register Should Be Equal                    ${X1}  0x1

    # this overwrites the `li` instruction
    # chaning the immediate value;
    # if the invalidation works fine, we should
    # observe the new value in the register
    # after running the code for the second time
    
    # li x1, 2
    Execute Command                             sysbus WriteDoubleWord 0x0 0x00200093

    Execute Command                             cpu PC 0x0
    Execute Command                             cpu SetRegister ${X1} 0x0
    Execute Command                             emulation RunFor "0.01"

    PC Should Be Equal                          0x4
    Register Should Be Equal                    ${X1}  0x2

Should Invalidate on Cross Page Word Write
    Create Machine

    # we use this particular PC as it's at the
    # edge of memory segments
    Execute Command                             cpu PC 0xfffffc

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0xfffffc 0x00100093

    # li x2, 1
    Execute Command                             sysbus WriteDoubleWord 0x1000000 0x00100113

    # j .
    Execute Command                             sysbus WriteDoubleWord 0x1000004 0x0000006f

    Execute Command                             cpu PC 0xfffffc
    Register Should Be Equal                    ${X1}  0x0
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x1
    Register Should Be Equal                    ${X2}  0x1
    Register Should Be Equal                    ${X3}  0x0

    # this single write modifies both `li` commands
    # so that the first one writes 0x131 instead of 0x1
    # and the second one writes to X2 instead of X1;
    # if the invalidation works fine, we should
    # observe new values in registers
    # after running the code for the second time
    Execute Command                             sysbus WriteWord 0xffffff 0x9313

    Execute Command                             cpu PC 0xfffffc
    Execute Command                             cpu SetRegister ${X1} 0x0
    Execute Command                             cpu SetRegister ${X2} 0x0
    Execute Command                             cpu SetRegister ${X3} 0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x131
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x1

Should Invalidate on Cross Page DoubleWord Write
    Create Machine

    # we use this particular PC as it's at the
    # edge of memory segments
    Execute Command                             cpu PC 0xfffffc

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0xfffffc 0x00100093

    # li x2, 1
    Execute Command                             sysbus WriteDoubleWord 0x1000000 0x00100113

    # j .
    Execute Command                             sysbus WriteDoubleWord 0x1000004 0x0000006f

    Execute Command                             cpu PC 0xfffffc
    Register Should Be Equal                    ${X1}  0x0
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x1
    Register Should Be Equal                    ${X2}  0x1
    Register Should Be Equal                    ${X3}  0x0

    # this single write modifies both `li` commands
    # so that the first one writes 0x131 instead of 0x1
    # and the second one writes to X2 instead of X1;
    # if the invalidation works fine, we should
    # observe new values in registers
    # after running the code for the second time
    Execute Command                             sysbus WriteDoubleWord 0xfffffe 0x01931310

    Execute Command                             cpu PC 0xfffffc
    Execute Command                             cpu SetRegister ${X1} 0x0
    Execute Command                             cpu SetRegister ${X2} 0x0
    Execute Command                             cpu SetRegister ${X3} 0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x131
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x1

Should Reduce Dirty Address List With Halted Cores
    Create Machine
    Create Log Tester                           0

    # add a second core that should not break the
    # dirty address list reduction mechanism
    Execute Command                             machine LoadPlatformDescriptionFromString "halted_cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty; allowUnalignedAccesses: true }"
    Execute Command                             halted_cpu IsHalted true

    Execute Command                             sysbus.cpu AssembleBlock 0x1000 "${PROG_DIRTY_ADDRESS}"

    Execute Command                             logLevel 0 cpu
    Execute Command                             logLevel 0 halted_cpu

    Execute Command                             emulation RunFor "0.01"

    Should Not Be In Log                        Attempted reduction of riscv dirty addresses list failed, .* CPUs that didn't fetch any:.*halted_cpu  treatAsRegex=true

Should Execute Modified Instruction After Unhalt
    [Documentation]  CPU core must execute code written by a second core while it was halted.
    Create Machine

    Execute Command                             machine LoadPlatformDescriptionFromString "reader: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty; allowUnalignedAccesses: true }"

    Execute Command                             reader AssembleBlock ${READER_ENTRY_PC} "${READER_PROGRAM}"
    Execute Command                             cpu AssembleBlock ${WRITER_ENTRY_PC} "${WRITER_PROGRAM}"

    # Run only the reader to populate translation cache.
    Execute Command                             cpu IsHalted true
    Execute Command                             reader PC ${READER_ENTRY_PC}
    Execute Command                             emulation RunFor "0.001"
    Register Should Be Equal                    ${X1}  1  cpuName=reader

    # Rewind the halted reader PC.
    Execute Command                             reader IsHalted true
    Execute Command                             reader PC ${READER_ENTRY_PC}

    # Overwrite the reader's instruction from the writer's thread.
    Execute Command                             cpu PC ${WRITER_ENTRY_PC}
    Execute Command                             cpu IsHalted false
    Execute Command                             emulation RunFor "0.001"

    # Start emulation and unhalt the reader while simulation is running.
    Execute Command                             start
    Execute Command                             reader IsHalted false
    Execute Command                             pause

    # Make sure the reader executes enough instructions to read the register.
    Execute Command                             emulation RunFor "0.001"
    Register Should Be Equal                    ${X1}  2  cpuName=reader
