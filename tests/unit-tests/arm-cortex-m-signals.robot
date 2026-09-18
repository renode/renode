*** Variables ***
${START_ADDRESS}                    0x100
${COUNTER_ADDRESS}                  0x4
${PLATFORM}                         @platforms/cpus/renesas-r7fa8m1a.repl

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

Run Command
    [Arguments]                     ${command}  ${prefix}=${EMPTY}
    ${raw}=                         Execute Command  ${command}
    ${result}=                      Evaluate  $raw.strip()
    Execute Command                 machine InfoLog "${prefix} - ${command} = ${result}"
    RETURN                          ${result}

Run Variable Increment Loop
    ${assembly}=                    catenate  SEPARATOR=${\n}
    ...                             nop  # this is here so we can see the PC has moved from the start
    ...                             loop:
    ...                             ldr r1, [r0]
    ...                             add r1, r1, #1
    ...                             str r1, [r0]
    ...                             b loop
    Execute Command                 cpu AssembleBlock ${START_ADDRESS} """${assembly}"""

    Execute Command                 cpu SetRegister "r0" ${COUNTER_ADDRESS}

    Execute Command                 cpu PC ${START_ADDRESS}
    Execute Command                 emulation RunFor "0.1s"

    ${counter_value}=               Run Command  sysbus ReadDoubleWord ${COUNTER_ADDRESS}
    RETURN                          ${counter_value}

*** Test Cases ***
CPU Wait Signal Should Stall CPU After Reset
    Create Machine

    ${counter_value}=               Run Variable Increment Loop

    Execute Command                 cpu CpuWaitSignal Set
    Execute Command                 cpu Reset

    ${counter_value_after}=         Run Variable Increment Loop

    Should Be Equal As Integers     ${counter_value}  ${counter_value_after}  counter should NOT have increased

CPU Wait Signal Should Not Stall CPU Before Reset
    Create Machine

    ${counter_value}=               Run Variable Increment Loop

    Execute Command                 cpu CpuWaitSignal Set

    ${counter_value_after}=         Run Variable Increment Loop

    Should Not Be Equal As Integers  ${counter_value}  ${counter_value_after}  counter should have increased

CPU Should Remember Wait Signal State Across Reset
    Create Machine

    Execute Command                 cpu CpuWaitSignal Set

    ${signal_before}=               Run Command  cpu CpuWaitSignal IsSet
    Execute Command                 cpu Reset
    ${signal_after}=                Run Command  cpu CpuWaitSignal IsSet

    Should Be Equal                 ${signal_before}  ${signal_after}  CPU Wait signal should remain set after Reset (before: ${signal_before}, after: ${signal_after})

CPU Wait Signal Should Unhalt CPU When Deasserted After Reset
    Create Machine

    Execute Command                 cpu CpuWaitSignal Set
    Execute Command                 cpu Reset

    Execute Command                 cpu PC ${START_ADDRESS}

    ${is_halted_before}=            Run Command  cpu IsHalted
    Execute Command                 cpu CpuWaitSignal Unset
    # After CPUWAIT is de-asserted, CPU is released from reset in the nearest synced state.
    Execute Command                 emulation RunToNearestSyncPoint
    ${is_halted_after}=             Run Command  cpu IsHalted

    Should Be Equal                 ${is_halted_before}  True  CPU should have halted but IsHalted=${is_halted_before}
    Should Be Equal                 ${is_halted_after}  False  CPU should have unhalted but IsHalted=${is_halted_after}

CPU Should Not Read Vector Table Until After CPU Wait Signal Is Deasserted
    Create Machine

    # Load some binary that has a vector table that the CPU should initialize SP/PC from.
    ${SOME_BINARY}=                 Set Variable  https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--agt.elf-s_391008-c0a91e7f3d279b86269ca83ac0aabb9936f94838
    Execute Command                 sysbus LoadELF @${SOME_BINARY}

    # Go into CPUWAIT-halted mode.
    Execute Command                 cpu CpuWaitSignal Set
    Execute Command                 cpu Reset

    Register Should Be Equal        SP  0x0
    Register Should Be Equal        PC  0x0

    Execute Command                 emulation RunFor "0.1s"

    # CPU shouldn't have read the vector table yet, as CPUWAIT is high.
    Register Should Be Equal        SP  0x0
    Register Should Be Equal        PC  0x0

    Execute Command                 cpu CpuWaitSignal Unset

    # After CPUWAIT is de-asserted, CPU is released from reset in the nearest synced state.
    Execute Command                 emulation RunToNearestSyncPoint

    # CPU should now have read the vector table and updated SP/PC accordingly.
    # Read initial values after release from reset.
    Register Should Be Equal        SP  0x220010D0
    Register Should Be Equal        PC  0x2001C20

Emulation Reset Should Halt CPU When CPU Wait Signal Set
    Create Log Tester               1
    Register Failing Log String     CPU abort

    Execute Command                 mach create
    # Define a platform that has CpuWaitSignal set already in the cpu's init block.
    ${base_platform}=               Get File  ${CURDIR}/../../platforms/cpus/renesas-r7fa8m1a.repl
    ${platform}=                    Catenate  SEPARATOR=${\n}
    ...                             ${base_platform}
    ...                             cpu: { isCpuWaitSignalSet: true }
    Execute Command                 machine LoadPlatformDescriptionFromString """${platform}"""

    # Set PC to a nonzero value outside of memory, so that the failing string below only triggers if IsHalted=false
    Execute Command                 cpu PC 0xdeadbeef

    # If this is printed then the CPU gets halted due to a reason other than CPUWAIT, which we don't want.
    Should Not Be In Log            PC does not lay in memory  timeout=0.01

    ${is_halted_after}=             Run Command  cpu IsHalted
    Should Be Equal                 ${is_halted_after}  True  CPU should have been halted by the CpuWaitSignal but IsHalted=${is_halted_after}

Should Stop NVIC SysTick and DWT CycleCounter When Not Clocked
    Execute Command                 i @platforms/cpus/atsamd51g19a.repl
    ${SOME_BINARY}=                 Set Variable  @https://dl.antmicro.com/projects/renode/adafruit_itsybitsy_m4_express-zephyr-shell_module.elf-s_1174688-96ba3690738a878b9f1d47e5ac677592a42c9040
    Execute Command                 sysbus LoadELF @${SOME_BINARY}

    Execute Command                 emulation RunFor "1"

    # Read NVIC SysTickValue and DWT CycleCounter registers
    ${SysTickValue0}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter0}=  Execute Command  dwt ReadDoubleWord 0x004

    Execute Command                 emulation RunFor "0.001"

    ${SysTickValue1}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter1}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm that both SysTick and CycleCounter are enabled (running).
    # It takes ~40 ms for SysTick counter to wrap.
    # Time is progressed by 1 ms (less than 40ms period)
    # so values are guaranteed to differ.
    Should Not Be Equal             ${SysTickValue0}  ${SysTickValue1}
    Should Not Be Equal             ${CycleCounter0}  ${CycleCounter1}

    # Stop Cortex-M tightly coupled peripherals.
    # Halting CPU is not enough, because SysTick and CycleCounter
    # are updated when clock source is advanced and it depends only
    # on virtual time progress. Clock source is stopped when machine
    # is halted, but here we want to verify clocking on a more granular level,
    # specifically for Cortex-M complex.
    Execute Command                 nvic Clocked False
    Execute Command                 dwt Clocked False

    Execute Command                 emulation RunFor "0.001"

    ${SysTickValue2}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter2}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm that both SysTick and CycleCounter were not advanced while not clocked.
    Should Be Equal             ${SysTickValue1}  ${SysTickValue2}
    Should Be Equal             ${CycleCounter1}  ${CycleCounter2}

    # Start Cortex-M tightly coupled peripherals.
    Execute Command                 nvic Clocked True
    Execute Command                 dwt Clocked True

    Execute Command                 emulation RunFor "0.001"

    ${SysTickValue3}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter3}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm that both SysTick and CycleCounter are resumed (running).
    Should Not Be Equal             ${SysTickValue2}  ${SysTickValue3}
    Should Not Be Equal             ${CycleCounter2}  ${CycleCounter3}

    # Disable clock only for SysTick to show that settings are independent.
    Execute Command                 nvic Clocked False
    Execute Command                 dwt Clocked True

    Execute Command                 emulation RunFor "0.001"

    ${SysTickValue4}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter4}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm that SysTick is stopped and CycleCounter is running.
    Should Be Equal                 ${SysTickValue3}  ${SysTickValue4}
    Should Not Be Equal             ${CycleCounter3}  ${CycleCounter4}

Should Persist Clocked State For Cortex-M Complex On Reset
    Execute Command                 i @platforms/cpus/atsamd51g19a.repl
    ${SOME_BINARY}=                 Set Variable  @https://dl.antmicro.com/projects/renode/adafruit_itsybitsy_m4_express-zephyr-shell_module.elf-s_1174688-96ba3690738a878b9f1d47e5ac677592a42c9040
    Execute Command                 sysbus LoadELF @${SOME_BINARY}

    # We are going to halt CPU later. If there is no work to do by CPU,
    # virtual time skyrockets and goes much ahead of wall time.
    # When CPU gets unhalted, it waits until wall time aligns to virtual time.
    # Without AdvanceImmediately mode, it takes ages (possibly hours of wall time).
    Execute Command                 emulation SetAdvanceImmediately True

    Execute Command                 emulation RunFor "1"

    Execute Command                 cpu0 Clocked False
    Execute Command                 nvic Clocked False
    Execute Command                 dwt Clocked False

    # Disabled clock state should persist across reset.
    Execute Command                 cpu0 Reset
    Execute Command                 nvic Reset
    Execute Command                 dwt Reset

    # Confirm CPU was reset.
    ${ExecutedInstructions0}=  Execute Command  cpu0 ExecutedInstructions
    Should Contain             ${ExecutedInstructions0}  0x0000000000000000

    ${SysTickValue4}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter4}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm SysTick and CycleCounter were reset.
    Should Contain             ${SysTickValue4}  0x00FFFFFF
    Should Contain             ${CycleCounter4}  0x00000000

    Execute Command                 emulation RunFor "1"

    ${SysTickValue5}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter5}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm SysTick and CycleCounter are not clocked.
    Should Be Equal                ${SysTickValue5}  ${SysTickValue4}
    Should Be Equal                ${CycleCounter5}  ${CycleCounter4}

    # Confirm CPU was inactive while not clocked.
    ${ExecutedInstructions1}=  Execute Command  cpu0 ExecutedInstructions
    Should Be Equal            ${ExecutedInstructions0}  ${ExecutedInstructions1}

    # Start CPU and tightly coupled peripherals.
    Execute Command                 cpu0 Clocked True
    Execute Command                 nvic Clocked True
    Execute Command                 dwt Clocked True

    Execute Command                 emulation RunFor "0.001"

    ${SysTickValue6}=  Execute Command  nvic ReadDoubleWord 0x018
    ${CycleCounter6}=  Execute Command  dwt ReadDoubleWord 0x004

    # Confirm that both SysTick and CycleCounter are running.
    Should Not Be Equal             ${SysTickValue6}  ${SysTickValue5}
    Should Not Be Equal             ${CycleCounter6}  ${CycleCounter5}
