*** Variables ***
${SIMULATION_TIME}            "0.001"
${TRACE_SIZE_LIMIT}           100
${URL}                        https://dl.antmicro.com/projects/renode
${PLAT_RISCV}                 SEPARATOR=\n  """
...                           cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32i"}
...                           mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x1000 }
...                           """
# The program is constructed in such a way that will insert stack announcements (jal x1, XX(x))
# but also chain blocks such that we have multiple stack announcements in a single block
${PROG_RISCV}                 SEPARATOR=\n
...                           loop:
...                               jal x1, 4
...                               jal x1, 4
...                               jal x1, 4
...                               jal loop

*** Keywords ***
Create Machine
    Execute Command           set bin @${URL}/renode-mbed-pipeline-helloworld.elf-ga2ede71-s_2466384-6e3635e4ed159bc847cf1deb3dc7f24b10d26b41
    Execute Command           include @scripts/single-node/stm32f746_mbed.resc

Create Machine With Chained Stack Announcements
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescriptionFromString ${PLAT_RISCV}

    Execute Command           cpu AssembleBlock 0x1000 "${PROG_RISCV}"

*** Test Cases ***
Should Stop Writing To File Perfetto
    Create Machine

    ${TEST_TRACE_FILE}=       Allocate Temporary File

    Execute Command           cpu EnableProfilerPerfetto "${TEST_TRACE_FILE}" true true ${TRACE_SIZE_LIMIT}
    Execute Command           emulation RunFor ${SIMULATION_TIME}

    ${TRACE_FILE_SIZE}=       Get File Size  ${TEST_TRACE_FILE}
    Should Be True            ${TRACE_FILE_SIZE} < ${TRACE_SIZE_LIMIT}

Should Stop Writing To File Collapsed Stack
    Create Machine

    ${TEST_TRACE_FILE}=       Allocate Temporary File

    Execute Command           cpu EnableProfilerCollapsedStack "${TEST_TRACE_FILE}" true ${TRACE_SIZE_LIMIT}
    Execute Command           emulation RunFor ${SIMULATION_TIME}

    ${TRACE_FILE_SIZE}=       Get File Size  ${TEST_TRACE_FILE}
    Should Be True            ${TRACE_FILE_SIZE} < ${TRACE_SIZE_LIMIT}

Should Not Limit File Size
    Create Machine

    ${TEST_TRACE_FILE}=       Allocate Temporary File

    Execute Command           cpu EnableProfilerCollapsedStack "${TEST_TRACE_FILE}" true
    Execute Command           emulation RunFor ${SIMULATION_TIME}

    ${TRACE_FILE_SIZE}=       Get File Size  ${TEST_TRACE_FILE}
    Should Be True            ${TRACE_FILE_SIZE} > ${TRACE_SIZE_LIMIT}

Should Disable Profiler Inside Translation Block
    Create Machine With Chained Stack Announcements

    # The mechanism that disables profiler can trigger it during the execution of a translation block
    # which means that it can still trigger a stack announcement even after flushing the translation cache
    # This test verifies that this case is handled
    Execute Command           cpu EnableProfilerCollapsedStack "profile" true 1000
    Execute Command           emulation RunFor "0.001"
