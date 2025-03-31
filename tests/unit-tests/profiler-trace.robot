*** Variables ***
${SIMULATION_TIME}            "0.001"
${TRACE_SIZE_LIMIT}           100
${URL}                        https://dl.antmicro.com/projects/renode
${PLAT_RISCV}                 SEPARATOR=\n  """
...                           cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32i"}
...                           mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x1000 }
...                           """
${PLAT_ARM}                   SEPARATOR=\n  """
...                           cpu: CPU.CortexM @ sysbus
...                           ${SPACE*4}cpuType: "cortex-m4"
...                           ${SPACE*4}nvic: nvic
...
...                           nvic: IRQControllers.NVIC @ sysbus 0xe000e000
...                           ${SPACE*4}-> cpu@0
...
...                           mem: Memory.MappedMemory @ sysbus 0x0
...                           ${SPACE*4}size: 0x4000
...                           """
# The program is constructed in such a way that will insert stack announcements (jal x1, XX(x))
# but also chain blocks such that we have multiple stack announcements in a single block
${PROG_RISCV}                 SEPARATOR=\n
...                           loop:
...                               jal x1, 4
...                               jal x1, 4
...                               jal x1, 4
...                               jal loop
# The code below configures MPU region 0 to <0x3000 0x64> to no priviliges, and then
# triggers the PendSV interrupt. In the PendSV handler the MPU fauilt is triggered, resulting
# in two execution stacks for one context.
${PROG_ARM}                   SEPARATOR=\n
...                           ldr r0, =0xE000ED9C  // MPU_RBAR
...                           ldr r1, [r0]
...                           orr r1, r1, #0x3000  // Base address 0x3000
...                           orr r1, r1, #0x8     // Region enabled
...                           str r1, [r0]
...
...                           ldr r0, =0xE000EDA0  // MPU_RASR
...                           ldr r1, [r0]
...                           orr r1, r1, #0xB     // Size 64, no R/W priv
...                           str r1, [r0]
...
...                           ldr r0, =0xE000ED94  // MPU_CTRL
...                           ldr r1, [r0]
...                           orr r1, r1, #0x7     // Enable MPU
...                           str r1, [r0]
...
...                           ldr r0, =0xE000ED04  // SCB->ICSR
...                           ldr r1, [r0]
...                           orr r1, r1, #0x10000000  // Trigger PENDSVSET
...                           str r1, [r0]
${PROG_ARM_HANDLER}           SEPARATOR=\n
...                           // Trigger MemManageFault
...                           ldr r0, =0x3000
...                           ldr r1, [r0]

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

Should Disable Profiler After Reaching Maximum Nested Context Count
    Create Log Tester         0
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescriptionFromString ${PLAT_ARM}

    ${TEST_TRACE_FILE}=       Allocate Temporary File
    Execute Command           cpu EnableProfilerCollapsedStack "${TEST_TRACE_FILE}" maximumNestedContexts=1

    # This sample will generate a nested interrupt: the first one is triggered by a PendSV, and the second
    # is caused by a MemManageFault due to accessing memory restricted by the MPU. The `maximumNestedContexts`
    # parameter is set to one, so it should disable the profiler upon the second interrupt.
    Execute Command           cpu AssembleBlock 0x2000 "${PROG_ARM}"
    Execute Command           cpu AssembleBlock 0x1000 "${PROG_ARM_HANDLER}"


    Execute Command           sysbus WriteDoubleWord 0x00 0x100   # Initial SP
    Execute Command           sysbus WriteDoubleWord 0x04 0x2000  # Initial PC
    Execute Command           sysbus WriteDoubleWord 0x38 0x1001  # PendSV Handler @ 0x1000
    Execute Command           cpu VectorTableOffset 0x0

    
    Execute Command           cpu Step 19
    Wait For Log Entry        maximum nested contexts exceeded, disabling profiler
