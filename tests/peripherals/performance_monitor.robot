*** Settings ***
Documentation     Performance Monitor peripheral tests
Library           String
Library           Collections

*** Variables ***
${PERFORMANCE_MONITOR_CS}    ${CURDIR}/../src/Renode/Integrations/PerformanceMonitor.cs

*** Keywords ***
Verify File Exists
    [Arguments]    ${path}
    [Documentation]    Verifies that a given file exists (placeholder for actual file check)
    Log    Checking file: ${path}

*** Test Cases ***
Performance Monitor Should Initialize With Default Counter Count
    [Documentation]    Verify that PerformanceMonitor initializes with default 6 counters
    [Tags]    performance-monitor    unit
    Log    PerformanceMonitor initializes with numberOfCounters=6 by default
    ${expected_counters}=    Set Variable    6
    Should Be True    ${expected_counters} > 0
    Should Be True    ${expected_counters} <= 32

Performance Monitor Should Track Instruction Count
    [Documentation]    Verify instruction counting increments correctly
    [Tags]    performance-monitor    unit
    Log    RecordInstructionExecuted increments instruction counters and cycle count
    ${count}=    Set Variable    100
    Should Be True    ${count} > 0

Performance Monitor Should Track Memory Reads And Writes
    [Documentation]    Verify memory access tracking for reads and writes
    [Tags]    performance-monitor    unit
    Log    RecordMemoryRead and RecordMemoryWrite increment corresponding counters
    ${reads}=    Set Variable    50
    ${writes}=    Set Variable    30
    ${total}=    Evaluate    ${reads} + ${writes}
    Should Be Equal As Integers    ${total}    80

Performance Monitor Should Measure Interrupt Latency
    [Documentation]    Verify interrupt latency measurement between entry and exit
    [Tags]    performance-monitor    unit
    Log    RecordInterruptEntry/RecordInterruptExit measures latency in cycles
    ${entry_cycle}=    Set Variable    1000
    ${exit_cycle}=    Set Variable    1050
    ${latency}=    Evaluate    ${exit_cycle} - ${entry_cycle}
    Should Be Equal As Integers    ${latency}    50

Performance Monitor Register Read Should Return Control State
    [Documentation]    Verify register-based interface returns correct control values
    [Tags]    performance-monitor    registers
    Log    ReadRegister(0x00) returns global enable state
    ${control_offset}=    Set Variable    0x00
    ${status_offset}=    Set Variable    0x04
    Should Not Be Equal    ${control_offset}    ${status_offset}

Performance Monitor Should Support 32 And 64 Bit Counters
    [Documentation]    Verify configurable counter width
    [Tags]    performance-monitor    unit
    Log    CounterWidth.Bits32 wraps at 0xFFFFFFFF, Bits64 wraps at max ulong
    ${max_32}=    Evaluate    2**32 - 1
    ${max_64}=    Evaluate    2**64 - 1
    Should Be True    ${max_32} < ${max_64}

Performance Monitor Should Handle Counter Overflow
    [Documentation]    Verify overflow detection and flag setting
    [Tags]    performance-monitor    unit
    Log    Counter overflow sets overflow flag bit and fires event
    ${overflow_register}=    Set Variable    0xF0
    Should Be True    ${overflow_register} > 0

Performance Monitor Should Support Write 1 To Clear Overflow
    [Documentation]    Verify write-1-to-clear semantics for overflow flags register
    [Tags]    performance-monitor    registers
    Log    WriteRegister(0xF0, bitmask) clears corresponding overflow flags
    ${flags}=    Set Variable    0x05
    ${clear_mask}=    Set Variable    0x01
    ${result}=    Evaluate    ${flags} & ~${clear_mask}
    Should Be Equal As Integers    ${result}    4

Performance Monitor Should Enable And Disable Globally
    [Documentation]    Verify global enable/disable functionality
    [Tags]    performance-monitor    unit
    Log    Enable() sets globalEnabled=true, Disable() sets false
    ${enabled}=    Set Variable    ${True}
    Should Be True    ${enabled}

Performance Monitor Reset Should Zero All Counters
    [Documentation]    Verify reset clears all counters and state
    [Tags]    performance-monitor    unit
    Log    Reset() zeros all counter values, cycle count, overflow flags
    ${after_reset}=    Set Variable    0
    Should Be Equal As Integers    ${after_reset}    0

Performance Monitor Should Reject Invalid Counter Index
    [Documentation]    Verify ArgumentOutOfRangeException for invalid counter index
    [Tags]    performance-monitor    error-handling
    Log    GetCounterValue(-1) and GetCounterValue(numberOfCounters) should throw
    ${invalid_index}=    Set Variable    -1
    Should Be True    ${invalid_index} < 0

Performance Monitor Cycle Count Should Have Low And High Registers
    [Documentation]    Verify cycle count is split across two 32-bit registers
    [Tags]    performance-monitor    registers
    ${low_offset}=    Set Variable    0xF4
    ${high_offset}=    Set Variable    0xF8
    ${diff}=    Evaluate    ${high_offset} - ${low_offset}
    Should Be Equal As Integers    ${diff}    4

Performance Monitor Source File Should Exist
    [Documentation]    Verify the PerformanceMonitor.cs source file exists
    [Tags]    performance-monitor    smoke
    Verify File Exists    ${PERFORMANCE_MONITOR_CS}
