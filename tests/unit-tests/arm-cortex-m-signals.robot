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

    Execute Command                 emulation RunFor "0.1s"

    # CPU should now have read the vector table and updated SP/PC accordingly.
    Register Should Be Equal        SP  0x22001038
    Register Should Be Equal        PC  0x2000520

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
