*** Variables ***
${PLATFORM}                         SEPARATOR=
...                                 """                                                    ${\n}
...                                 cpu: CPU.ARMv7A @ sysbus                               ${\n}
...                                 ${SPACE*4}cpuType: "cortex-a9"                         ${\n}
...                                                                                        ${\n}
...                                 pmu: Miscellaneous.ArmPerformanceMonitoringUnit @ {    ${\n}
...                                 ${SPACE*8}cpu;                                         ${\n}
...                                 ${SPACE*8}sysbus new Bus.BusRangeRegistration {        ${\n}
...                                 ${SPACE*8}${SPACE*4}address: ${MMIO_ADDRESS};          ${\n}
...                                 ${SPACE*8}${SPACE*4}size: 0x1000                       ${\n}
...                                 ${SPACE*8}}                                            ${\n}
...                                 ${SPACE*4}}                                            ${\n}
...                                 ${SPACE*4}peripheralId: ${PERIPHERAL_ID}               ${\n}
...                                 ${SPACE*4}withProcessorIdMMIORegisters: true           ${\n}
...                                                                                        ${\n}
...                                 memory: Memory.MappedMemory @ sysbus 0x0               ${\n}
...                                 ${SPACE*4}size: 0x20000                                ${\n}
...                                 """

${BOGUS_EVENT_1}                    0x1
${BOGUS_EVENT_2}                    0xAB
${SOFTWARE_INCREMENT_EVENT}         0x00
${INSTRUCTIONS_EVENT}               0x8
${CYCLES_EVENT}                     0x11

${CPU_MIDR}                         0x410fc090
${MMIO_ADDRESS}                     0xF0000000
${MMIO_SOFTWARE_LOCK_KEY}           0xC5ACCE55
${PERIPHERAL_ID}                    0xFEDCBA9876543210
${REG_ID_PFR1_OFFSET}               0xD24
${REG_MIDR_OFFSET}                  0xD00
${REG_MPUIR_OFFSET}                 0xD10
${REG_PMCCNTR_OFFSET}               0x07C
${REG_PMCNTENSET_OFFSET}            0xC00
${REG_PMCR_OFFSET}                  0xE04
${REG_PMLAR_OFFSET}                 0xFB0  # MMIO-only register
${REG_PMPID0_OFFSET}                0xFE0
${REG_PMPID2_OFFSET}                0xFE8
${REG_PMPID4_OFFSET}                0xFD0
${REG_PMSWINC_OFFSET}               0xCA0
${REG_PMXEVCNTR0_OFFSET}            0x000
${REG_PMXEVCNTR30_OFFSET}           0x078
${REG_PMXEVTYPER0_OFFSET}           0x400
${REG_PMXEVTYPER30_OFFSET}          0x478
${REG_TLBTR_OFFSET}                 0xD0C

*** Keywords ***
Create Machine
    # Some keywords expect numbers to be printed as hex.
    Execute Command                 numbersMode Hexadecimal

    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}

    # Create infinite loop
    Execute Command                 sysbus WriteDoubleWord 0x1000 0xE320F000  # nop
    Execute Command                 sysbus WriteDoubleWord 0x1004 0xEAFFFFFD  # b to 0x1000

    # Set predefined PerformanceInMips, so it's possible to calculate
    # the number of expected instructions to execute in the given time frame
    Execute Command                 cpu PerformanceInMips 100
    Execute Command                 cpu PC 0x1000

Set Register Bits
    [Arguments]                     ${regName}  ${value}
    ${enabledCounters}=             Execute Command  cpu.pmu GetRegister ${regName}
    ${mask}=                        Evaluate  hex(int($enabledCounters, 16) | int($value))

    Execute Command                 cpu.pmu SetRegister ${regName} ${mask}

Clear Register Bits
    [Arguments]                     ${regName}  ${value}
    ${enabledCounters}=             Execute Command  cpu.pmu GetRegister ${regName}
    ${mask}=                        Evaluate  hex(int($enabledCounters, 16) & ~int($value))

    Execute Command                 cpu.pmu SetRegister ${regName} ${mask}

Assert Bit Set
    [Arguments]                     ${value}  ${bit}
    ${isSet}=                       Evaluate  (${value} & (1 << ${bit})) > 0
    Should Be True                  ${isSet}

Assert Bit Unset
    [Arguments]                     ${value}  ${bit}
    ${isNotSet}=                    Evaluate  (${value} & (1 << ${bit})) == 0
    Should Be True                  ${isNotSet}

Enable PMU
    Set Register Bits               "PMCR"  1

Disable PMU
    Clear Register Bits             "PMCR"  1

Reset PMU Counters
    Set Register Bits               "PMCR"  2

Reset PMU Cycle Counter
    Set Register Bits               "PMCR"  4

Set Cycles Divisor 64
    [Arguments]                     ${divisor}
    IF  ${divisor}
        Set Register Bits               "PMCR"  8
    ELSE
        Clear Register Bits             "PMCR"  8
    END

Switch Privilege Mode
    [Arguments]                     ${privileged}
    # use CPSR to switch between PL0/PL1
    IF  ${privileged}  # PL1 - SVC mode
        ${cpsr}=                        Execute Command  cpu CPSR
        ${cpsr}=                        Evaluate  (int(${cpsr}) & ~0x1F ) | 0x13
        Execute Command                 cpu CPSR ${cpsr}
    ELSE  # PL0
        ${cpsr}=                        Execute Command  cpu CPSR
        ${cpsr}=                        Evaluate  (int(${cpsr}) & ~0x1F ) | 0x10
        Execute Command                 cpu CPSR ${cpsr}
    END

Enable PMU Counter
    [Arguments]                     ${counter}
    ${value}=                       Evaluate  (1 << int($counter))

    Set Register Bits               "PMCNTENSET"  ${value}

Disable PMU Counter
    [Arguments]                     ${counter}
    ${value}=                       Evaluate  (1 << int($counter))

    Execute Command                 cpu.pmu SetRegister "PMCNTENCLR" ${value}

Enable Overflow Interrupt For PMU Counter
    [Arguments]                     ${counter}
    ${value}=                       Evaluate  (1 << int($counter))

    Execute Command                 cpu.pmu SetRegister "PMINTENSET" ${value}

Disable Overflow Interrupt For PMU Counter
    [Arguments]                     ${counter}
    ${value}=                       Evaluate  (1 << int($counter))

    Execute Command                 cpu.pmu SetRegister "PMINTENCLR"  ${value}

Increment Software PMU Counter
    [Arguments]                     ${counter}
    ${value}=                       Evaluate  (1 << int($counter))

    Execute Command                 cpu.pmu SetRegister "PMSWINC" ${value}

Assert PMU Counter Is Equal To
    [Arguments]                     ${counter}  ${value}
    ${cnt}=                         Execute Command  cpu.pmu GetCounterValue ${counter}

    Should Be Equal As Integers     ${cnt}  ${value}

Assert Executed Instructions Equal To
    [Arguments]                     ${value}
    ${executedInstructions}=        Execute Command  cpu ExecutedInstructions

    Should Be Equal As Integers     ${executedInstructions}  ${value}

Assert PMU Cycle Counter Equal To
    [Arguments]                     ${value}
    ${cycles}=                      Execute Command  cpu.pmu GetCycleCounterValue

    Should Be Equal As Integers     ${cycles}  ${value}

Assert PMU IRQ Is Set
    ${irqState}=                    Execute Command  cpu.pmu IRQ
    Should Contain                  ${irqState}  GPIO: set

Assert PMU IRQ Is Unset
    ${irqState}=                    Execute Command  cpu.pmu IRQ
    Should Contain                  ${irqState}  GPIO: unset

Assert PMU Counter Overflowed
    [Arguments]                     ${counter}
    # n-th bit denotes overflow status for the n-th PMU counter
    ${overflowStatus}=              Execute Command  cpu.pmu GetRegister "PMOVSR"
    Assert Bit Set                  ${overflowStatus}  ${counter}

Assert PMU Counter Not Overflowed
    [Arguments]                     ${counter}
    ${overflowStatus}=              Execute Command  cpu.pmu GetRegister "PMOVSR"
    Assert Bit Unset                ${overflowStatus}  ${counter}

Assert Command Output Equal To
    [Arguments]                     ${expectedOutput}  ${command}
    ${output}=                      Execute Command  ${command}
    Should Be Equal                 ${output}  ${expectedOutput}  strip_spaces=True

Get ${name} Register Offset
    ${variableName}=  Set Variable  ${{ "REG_" + "${name}" + "_OFFSET" }}
    RETURN  ${ ${variableName} }

MMIO-Accessed ${name} Should Be Equal To Value ${expectedValue}
    ${offset}=                      Get ${name} Register Offset
    ${output}=                      Execute Command  sysbus ReadDoubleWord ${{ ${MMIO_ADDRESS} + ${offset} }}
    Should Be Equal As Integers     ${output}  ${expectedValue}

MMIO-Accessed ${name} Should Be Equal To System Register
    # There are no direct PMXEVCNTR and PMXEVTYPER system registers for all counters but only
    # two such registers depending on PMSELR so PMU wrapping methods have to be used instead.
    IF  "${name}".startswith("PMXEVCNTR")
        ${expectedValue}=           Execute Command  cpu.pmu GetCounterValue ${{ int("${name}".replace("PMXEVCNTR", "")) }}
    ELSE IF  "${name}".startswith("PMXEVTYPER")
        ${expectedValue}=           Execute Command  cpu.pmu GetCounterEvent ${{ int("${name}".replace("PMXEVTYPER", "")) }}
    ELSE
        ${expectedValue}=           Execute Command  cpu GetSystemRegisterValue "${name}"
    END

    MMIO-Accessed ${name} Should Be Equal To Value ${expectedValue}

Write ${value} To ${name} Using MMIO
    ${offset}=                      Get ${name} Register Offset
    Execute Command                 sysbus WriteDoubleWord ${{ ${MMIO_ADDRESS} + ${offset} }} ${value}

Unlock MMIO Writes
    Write ${MMIO_SOFTWARE_LOCK_KEY} To PMLAR Using MMIO

*** Test Cases ***
Should Count Cycles
    Create Machine

    Enable PMU
    Enable PMU Counter              31  # Cycle counter

    Execute Command                 emulation RunFor "00:00:01.12"

    # Given a known PerformanceInMIPS, it can be assumed that 112 000 000 instructions have been executed
    Assert PMU Cycle Counter Equal To  112 000 000
    Assert Executed Instructions Equal To  112 000 000

Should Count Cycles With Divisor
    Create Machine
    Enable PMU Counter              31  # Cycle counter
    Enable PMU
    Set Cycles Divisor 64           ${True}

    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  1000000
    Assert PMU Cycle Counter Equal To  15625

    Set Cycles Divisor 64           ${False}

    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  2000000
    Assert PMU Cycle Counter Equal To  1015625

Should Program PMU Counter To Count Cycles
    Create Machine

    Enable PMU
    Execute Command                 cpu.pmu SetCounterEvent 0 ${CYCLES_EVENT}
    Enable PMU Counter              0

    Execute Command                 emulation RunFor "00:00:01.12"

    # As above, given PerformanceInMIPS, we know how many instructions to expect
    # One cycle is equal to one instruction, this is not a mistake
    Assert Executed Instructions Equal To  112 000 000
    Assert PMU Counter Is Equal To  0  112 000 000

    # Now, an instruction should be equal to 1.25 cycles
    Execute Command                 cpu CyclesPerInstruction 1.25
    Execute Command                 emulation RunFor "00:00:00.01"

    # Executed 1 000 000 instructions, so 1 250 000 cycles
    Assert Executed Instructions Equal To  113 000 000
    Assert PMU Counter Is Equal To  0  113 250 000

Should Program PMU Counter To Count Instructions
    Create Machine

    # Cycles value will be used in dependent tests
    Enable PMU Counter              31
    Enable PMU
    Execute Command                 cpu.pmu SetCounterEvent 0 ${INSTRUCTIONS_EVENT}
    Enable PMU Counter              0

    Execute Command                 emulation RunFor "00:00:01.12"
    Assert Executed Instructions Equal To  112 000 000
    Assert PMU Counter Is Equal To  0  112 000 000

    Provides                        program-counter

Should Reset PMU counters
    Requires                        program-counter

    Assert PMU Counter Is Equal To  0  112 000 000
    Reset PMU Counters
    Assert PMU Counter Is Equal To  0  0

    Assert PMU Cycle Counter Equal To  112 000 000
    Reset PMU Cycle Counter
    Assert PMU Cycle Counter Equal To  0

Should Kick Software Increment
    Create Machine

    # Configure PMU counters, only Counter 0 subscribes to Software Increment event, Counter 1 subscribes to non-implemented event
    # So only Counter 0 is expected to be incremented
    Execute Command                 cpu.pmu SetCounterEvent 0 ${SOFTWARE_INCREMENT_EVENT}
    Execute Command                 cpu.pmu SetCounterEvent 1 ${BOGUS_EVENT_1}

    # Verify the configured events by reading their event ids
    ${ev1}=                         Execute Command  cpu.pmu GetCounterEvent 1
    ${ev0}=                         Execute Command  cpu.pmu GetCounterEvent 0
    Should Be Equal As Integers     ${ev1}  1
    Should Be Equal As Integers     ${ev0}  0

    Increment Software PMU Counter  0
    Increment Software PMU Counter  1

    # Counters and PMU are disabled, should not count
    Assert PMU Counter Is Equal To  0  0
    Assert PMU Counter Is Equal To  1  0

    Enable PMU Counter              0

    Increment Software PMU Counter  1
    Increment Software PMU Counter  0

    # Still not counting, PMU is not enabled
    Assert PMU Counter Is Equal To  0  0
    Assert PMU Counter Is Equal To  1  0
    Enable PMU

    Increment Software PMU Counter  0
    Increment Software PMU Counter  1

    # PMU Counter 1 is not a Software Increment, so it shouldn't increment at all
    # Counter 0 is incremented only once, after "Enable PMU". Previous increments were invalid, since PMU was disabled
    Assert PMU Counter Is Equal To  0  1
    Assert PMU Counter Is Equal To  1  0

Should Respect PMU Counter Pasue And Resume
    Create Machine
    Enable PMU

    Execute Command                 cpu.pmu SetCounterEvent 1 ${CYCLES_EVENT}
    Enable PMU Counter              1
    Execute Command                 emulation RunFor "00:00:00.01"

    Assert PMU Counter Is Equal To  1  1000000
    Assert Executed Instructions Equal To  1000000

    # Shouldn't count with disabled PMU
    Disable PMU
    Execute Command                 emulation RunFor "00:00:00.01"

    Assert PMU Counter Is Equal To  1  1000000
    Assert Executed Instructions Equal To  2000000

    Enable PMU
    Execute Command                 emulation RunFor "00:00:00.01"

    Assert PMU Counter Is Equal To  1  2000000
    Assert Executed Instructions Equal To  3000000

    # Shouldn't count when the counter is disabled
    Disable PMU Counter             1
    Execute Command                 emulation RunFor "00:00:00.01"

    Assert PMU Counter Is Equal To  1  2000000
    Assert Executed Instructions Equal To  4000000

    Enable PMU Counter              1
    Execute Command                 emulation RunFor "00:00:00.01"

    Assert PMU Counter Is Equal To  1  3000000
    Assert Executed Instructions Equal To  5000000

Should Trigger Cycles Overflow
    Create Machine

    Enable PMU

    ## Counter 2
    # The performance in MIPS is known, so it's possible to calculate the exact moment the counter should overflow
    # Configure counter, so after 3 000 000 instructions it should have overflowed and have the value 2 stored
    # so it's set to "UINT32_MAX - value + 3"
    Execute Command                 cpu.pmu SetCounterEvent 2 ${CYCLES_EVENT}
    Execute Command                 cpu.pmu SetCounterValue 2 0xFFD23942
    Enable Overflow Interrupt For PMU Counter  2
    Enable PMU Counter              2

    ## Counter 1
    Execute Command                 cpu.pmu SetCounterEvent 1 ${CYCLES_EVENT}
    # expected to execute 1 000 000 instructions, so load "UINT32_MAX - value" to counter
    # it is expected to overflow one instruction after
    Execute Command                 cpu.pmu SetCounterValue 1 0xFFF0BDBF
    Enable Overflow Interrupt For PMU Counter  1
    Enable PMU Counter              1

    # See that it didn't overflow too soon
    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  1000000
    # The value is counter's base value "0xFFF0BDBF" + 1 000 000 expected instructions to execute
    Assert PMU Counter Is Equal To  1  0xFFFFFFFF
    Assert PMU Counter Not Overflowed  1
    Assert PMU IRQ Is Unset

    # It will overflow 1 instruction after, we now execute 100 000, so overflow bit has to be set
    Execute Command                 emulation RunFor "00:00:00.001"
    Assert PMU Counter Overflowed   1
    Assert PMU IRQ Is Set

    Provides                        cycles-overflow

Should Resume Execution After Cycles Overflow
    Requires                        cycles-overflow

    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  2100000
    # instructions are counted from 0 after overflow, so instead from 1 000 000 + 100 000 subtract 1
    Assert PMU Counter Is Equal To  1  1099999

    Provides                        resumed-after-overflow

Should Overflow Second Time
    Requires                        resumed-after-overflow
    # Clear overflow bit for counter 1
    Execute Command                 cpu.pmu SetRegister "PMOVSR" 0x2

    Execute Command                 emulation RunFor "00:00:00.009"
    Assert Executed Instructions Equal To  3000000
    Assert PMU Counter Is Equal To  2  2

    Assert PMU Counter Overflowed   2

Should Increment Bogus Event From Monitor
    # The event is unimplemented, and there will be warnings in the logs
    # but still can be used it in a test scenario
    Create Machine

    Enable PMU
    Execute Command                 cpu.pmu SetCounterEvent 1 ${BOGUS_EVENT_2}
    Enable PMU Counter              1

    Execute Command                 cpu.pmu BroadcastEvent ${BOGUS_EVENT_2} 5
    Assert PMU Counter Is Equal To  1  5

    # now, let's overflow
    Enable Overflow Interrupt For PMU Counter  1
    Execute Command                 cpu.pmu BroadcastEvent ${BOGUS_EVENT_2} 0xFFFFFFFF
    Assert PMU Counter Is Equal To  1  4

    Assert PMU Counter Overflowed   1
    Assert PMU IRQ Is Set

Should Count Instructions With PL Masking
    Create Machine

    Enable PMU Counter              0
    Execute Command                 cpu.pmu SetCounterEvent 0 ${INSTRUCTIONS_EVENT} ignoreCountAtPL0=false ignoreCountAtPL1=true
    Enable PMU
    Enable Overflow Interrupt For PMU Counter  0

    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  1000000
    # The counter doesn't count at PL1, so should be zero
    Assert PMU Counter Is Equal To  0  0

    Switch Privilege Mode           ${False}
    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  2000000
    # The PMU counter only counted in PL0, so only 1 000 000 instructions
    Assert PMU Counter Is Equal To  0  1000000

    Execute Command                 cpu.pmu SetCounterEvent 0 ${INSTRUCTIONS_EVENT} ignoreCountAtPL0=true ignoreCountAtPL1=true
    # Now, counting at PL0 is disabled too, so PMU counter should not progress
    Execute Command                 emulation RunFor "00:00:00.01"
    Assert Executed Instructions Equal To  3000000
    Assert PMU Counter Is Equal To  0  1000000

    # See that the counter doesn't count and doesn't trigger overflow
    # Configure counter, so after 3 000 000 instructions it should have overflowed and have the value 2 stored
    # so it's set to "UINT32_MAX - value + 3"
    # But it shouldn't count anything at PL0
    Execute Command                 cpu.pmu SetCounterValue 0 0xFFD23942
    Execute Command                 emulation RunFor "00:00:00.03"
    Assert Executed Instructions Equal To  6000000
    # No progress for the couner
    Assert PMU Counter Is Equal To  0  0xFFD23942
    Assert PMU Counter Not Overflowed  0
    Assert PMU IRQ Is Unset

    # Now, switch the mode back to PL1 and enable counting events there
    Execute Command                 cpu.pmu SetCounterEvent 0 ${INSTRUCTIONS_EVENT} ignoreCountAtPL0=true ignoreCountAtPL1=false
    Switch Privilege Mode           ${True}

    # The counter hadn't progressed at all, so it's not necessary to set it's value again
    Execute Command                 emulation RunFor "00:00:00.03"
    Assert Executed Instructions Equal To  9000000
    Assert PMU Counter Is Equal To  0  2
    Assert PMU Counter Overflowed   0
    Assert PMU IRQ Is Set

Should Allow MMIO Writes Only After Disabling Software Lock
    Create Machine

    Create Log Tester               0
    Execute Command                 logLevel -1 pmu
    Assert Command Output Equal To  True  pmu SoftwareLockEnabled

    # Try writing.
    Write 0xAB To PMXEVTYPER0 Using MMIO
    Wait For Log Entry              write ignored
    Wait For Log Entry              Software Lock can be cleared by writing ${MMIO_SOFTWARE_LOCK_KEY} to the PMLAR register at ${REG_PMLAR_OFFSET}
    MMIO-Accessed PMXEVTYPER0 Should Be Equal To Value 0

    # Try unlocking with invalid key.
    ${invalidUnlockKey}=  Set Variable  0xABCD
    Write ${invalidUnlockKey} To PMLAR Using MMIO
    Wait For Log Entry              Tried to disable Software Lock with invalid value ${invalidUnlockKey}, should be ${MMIO_SOFTWARE_LOCK_KEY}
    Assert Command Output Equal To  True  pmu SoftwareLockEnabled

    # Unlock.
    Unlock MMIO Writes
    Wait For Log Entry              Software Lock disabled
    Assert Command Output Equal To  False  pmu SoftwareLockEnabled

    # Write again.
    Write ${BOGUS_EVENT_1} To PMXEVTYPER0 Using MMIO
    Should Not Be In Log            write ignored
    Wait For Log Entry              cpu: Invalid/Unimplemented event ${BOGUS_EVENT_1} selected for PMU counter 0
    MMIO-Accessed PMXEVTYPER0 Should Be Equal To Value ${BOGUS_EVENT_1}

Should Kick Software Incremented Counters Using MMIO
    Create Machine
    Unlock MMIO Writes

    # Enable PMU.
    Write 0x1 To PMCR Using MMIO

    # Set counters 0 and 30 to software increment event and enable them.
    Write ${SOFTWARE_INCREMENT_EVENT} To PMXEVTYPER0 Using MMIO
    Write ${SOFTWARE_INCREMENT_EVENT} To PMXEVTYPER30 Using MMIO
    Write ${{ (1 << 30) | 1 }} To PMCNTENSET Using MMIO

    # Increment counters using both MMIO and System Registers.
    Write 1 To PMSWINC Using MMIO
    Write ${{ 1 << 30 }} To PMSWINC Using MMIO
    Increment Software PMU Counter  30

    # Make sure the MMIO-accessed count is valid and equal to system registers.
    MMIO-Accessed PMXEVCNTR0 Should Be Equal To Value 1
    MMIO-Accessed PMXEVCNTR0 Should Be Equal To System Register
    MMIO-Accessed PMXEVCNTR30 Should Be Equal To Value 2
    MMIO-Accessed PMXEVCNTR30 Should Be Equal To System Register

Should Read Peripheral ID Using MMIO
    Create Machine

    ${peripheralId}=  Execute Command  pmu PeripheralId
    ${peripheralId}=  Strip String     ${peripheralId}

    # Peripheral ID's bits 20-23 should contain variant from bits 20-23 of MIDR.
    Should Be Equal As Integers     ${{ ((${peripheralId}^${CPU_MIDR}) >> 20) & 0xF }}  0

    # Each of PMPID0-PMPID7 contains 8 bits from PeripheralId.
    MMIO-Accessed PMPID0 Should Be Equal To Value ${{ ${peripheralId} & 0xFF }}
    MMIO-Accessed PMPID2 Should Be Equal To Value ${{ (${peripheralId} >> 16) & 0xFF }}
    MMIO-Accessed PMPID4 Should Be Equal To Value ${{ (${peripheralId} >> 32) & 0xFF }}

Should Read Processor ID System Registers Using MMIO
    Create Machine

    MMIO-Accessed ID_PFR1 Should Be Equal To System Register
    MMIO-Accessed MIDR Should Be Equal To System Register
    # MIDR is read for MPUIR because Cortex-A9 doesn't have MPU.
    MMIO-Accessed MPUIR Should Be Equal To Value ${CPU_MIDR}
    MMIO-Accessed TLBTR Should Be Equal To System Register

Should Read PMU Registers Using MMIO
    # Let's use a saved state with enabled cycle counter and counter 0 counting instructions.
    Requires                        program-counter

    # Compare PMU registers used in the case providing `program-counter` state.
    MMIO-Accessed PMXEVCNTR0 Should Be Equal To System Register
    MMIO-Accessed PMXEVTYPER0 Should Be Equal To System Register
    MMIO-Accessed PMCCNTR Should Be Equal To System Register
    MMIO-Accessed PMCNTENSET Should Be Equal To System Register
    MMIO-Accessed PMCR Should Be Equal To System Register
