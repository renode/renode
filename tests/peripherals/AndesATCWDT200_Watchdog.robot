*** Settings ***
Test Setup                          Create Machine
Library                             ${CURDIR}/AndesATCWDT200_Watchdog-helpers.py

*** Variables ***
${PLATFORM_PATH}                    @platforms/cpus/egis_et171.repl
${CORE_0_PC}                        0x80000000

# Register offsets
${IdAndRevision}                    0x00
${Reserved}                         0x04
${Control}                          0x10
${Restart}                          0x14
${WriteEnable}                      0x18
${Status}                           0x1C

# Control register flags
${SystemResetEnableBit}             3
${InterruptEnableBit}               2
${EnableBit}                        0

# Status register flags
${InterruptExpired}                 0

# Magic numbers
${ATCWDT200_WP_NUM}                 0x5AA5  # for Write Protection
${ATCWDT200_RESTART_NUM}            0xCAFE  # for restarting the watchdog timer

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM_PATH}

    # Have the core stuck in an infinite loop.
    Execute Command                 cpu0 PC ${CORE_0_PC}
    Execute Command                 cpu0 AssembleBlock ${CORE_0_PC} "j 0"

    Create Log Tester               timeout=0  defaultPauseEmulation=True
    Execute Command                 logLevel 0 watchdog

Read Watchdog Byte At ${offset}
    ${value}=                       Execute Command  watchdog ReadByteUsingDoubleWord ${offset}
    [return]                        ${value.strip()}

Write Watchdog Word ${value} To ${offset}
    Execute Command                 watchdog WriteWordUsingDoubleWord ${offset} ${value}

Write To ${offset} Is ${result:(Ignored|Allowed)}
    [Arguments]                     ${value}=0xAD
    ${initial_value}=               Read Watchdog Byte At ${offset}

    Execute Command                 watchdog WriteByteUsingDoubleWord ${offset} ${value}

    ${value}=                       Read Watchdog Byte At ${offset}
    IF  '${result}' == 'Ignored'
        Should Be Equal As Integers
        ...                             ${value}
        ...                             ${initial_value}
        ...                             Register should remain unchanged, but it changed from ${initial_value} to ${value}
    ELSE
        Should Not Be Equal As Integers
        ...                             ${value}
        ...                             ${initial_value}
        ...                             Register should change, but it did not: ${value}
    END

Set Watchdog Flag At Bit ${bit} In ${offset} To ${value:(0|1)}
    ${current_value}=               Execute Command  watchdog ReadDoubleWord ${offset}
    ${mask}=                        Set Variable  ${{ 1 << ${bit} }}
    IF  '${value}' == '0'
        ${negated_mask}=                Set Variable  ${{ ~${mask} }}
        ${new_value}=                   Set Variable  ${{ ${current_value.strip()} & ${negated_mask} }}
    ELSE
        ${new_value}=                   Set Variable  ${{ ${current_value.strip()} | ${mask} }}
    END
    Execute Command                 watchdog WriteDoubleWord ${offset} ${new_value}

Read Watchdog Flag At Bit ${bit} In ${offset}
    ${current_value}=               Execute Command  watchdog ReadDoubleWord ${offset}
    ${mask}=                        Set Variable  ${{ 1 << ${bit} }}
    ${flag_value}=                  Set Variable  ${{ ${current_value.strip()} & ${mask} }}
    [return]                        ${flag_value}

Enable Watchdog Timer
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Set Watchdog Flag At Bit ${EnableBit} In ${Control} To 1

Enable Watchdog Interrupt
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Set Watchdog Flag At Bit ${InterruptEnableBit} In ${Control} To 1

Disable Watchdog Interrupt
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Set Watchdog Flag At Bit ${InterruptEnableBit} In ${Control} To 0

Enable Watchdog System Reset
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Set Watchdog Flag At Bit ${SystemResetEnableBit} In ${Control} To 1

Restart Watchdog
    [Arguments]                     ${restart_value}=${ATCWDT200_RESTART_NUM}
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Write Watchdog Word ${restart_value} To ${Restart}

Watchdog IRQ Should Be ${expected_state:(High|Low)}
    [Arguments]                     ${message}=
    ${is_signal_set}=               Execute Command  watchdog IRQ IsSet
    ${actual_state}=                Set Variable If  '${is_signal_set.strip()}' == 'True'
    ...                             High
    ...                             Low
    Should Be Equal
    ...                             ${actual_state}
    ...                             ${expected_state}
    ...                             ${message} IRQ should be ${expected_state}, but it was ${actual_state}

Get Interrupt Timeout
    ${control}=                     Execute Command  watchdog ReadDoubleWord ${Control}
    ${frequency}=                   Execute Command  syscon APBClockFrequency
    ${seconds}=                     Get Interrupt Timeout Seconds  ${control}  ${frequency}
    Log To Console                  interrupt timeout is ${seconds}s
    [return]                        ${seconds}

Wait For Interrupt Timeout
    ${seconds}=                     Get Interrupt Timeout
    Execute Command                 emulation RunFor "${seconds}s"

Wait For Reset Timeout
    ${control}=                     Execute Command  watchdog ReadDoubleWord ${Control}
    ${frequency}=                   Execute Command  syscon APBClockFrequency
    ${seconds}=                     Get Reset Timeout Seconds  ${control}  ${frequency}
    Log To Console                  reset timeout is ${seconds}s
    Execute Command                 emulation RunFor "${seconds}s"

Watchdog IRQ Should Initially Be ${initial_value:(High|Low)} And After Timeout Be ${final_value:(High|Low)}
    Watchdog IRQ Should Be ${initial_value}  Initially,

    Wait For Interrupt Timeout

    Watchdog IRQ Should Be ${final_value}  After timeout,

Watchdog System Reset Should ${triggered:(Be|Not Be)} Triggered
    IF  '${triggered}' == 'Be'
        Wait For Log Entry              Reset timer elapsed
    ELSE
        Should Not Be In Log            Reset timer elapsed
    END

Watchdog System Reset Should Initially ${initial_value:(Be|Not Be)} Triggered And After Timeout ${final_value:(Be|Not Be)} Triggered
    Watchdog System Reset Should ${initial_value} Triggered

    Wait For Reset Timeout

    Watchdog System Reset Should ${final_value} Triggered

Write ${value} To Restart Register Periodically
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    # Watchdog interrupt should not be high initially.
    Watchdog IRQ Should Be Low

    ${interrupt_timeout_seconds}=   Get Interrupt Timeout
    # A duration that's small enough to not elapse the timer,
    # but big enough that several steps of this size _will_ elapse the timer.
    ${small_step}=                  Evaluate  ${interrupt_timeout_seconds}/3
    # Round it to avoid infinite decimals.
    ${small_step_rounded}=          Round To N Significant Digits  ${small_step}  3
    # Restart the watchdog periodically, so as to not trigger the interrupt.
    Execute Command                 emulation RunFor "${small_step_rounded}s"
    Restart Watchdog                ${value}
    Execute Command                 emulation RunFor "${small_step_rounded}s"
    Restart Watchdog                ${value}
    Execute Command                 emulation RunFor "${small_step_rounded}s"

Interrupt Status Register Flag Matches IRQ Signal
    ${interrupt_flag_value}=        Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    ${interrupt_flag}=              Set Variable If  '${interrupt_flag_value}' == '0'
    ...                             Low
    ...                             High

    ${is_signal_set}=               Execute Command  watchdog IRQ IsSet
    ${interrupt_signal}=            Set Variable If  '${is_signal_set.strip()}' == 'False'
    ...                             Low
    ...                             High

    Should Be Equal                 ${interrupt_flag}  ${interrupt_signal}  Expected interrupt flag (${interrupt_flag}) and signal (${interrupt_signal}) to match

*** Test Cases ***
Write To Read-Only ID And Revision Register Is Ignored
    Write To ${IdAndRevision} Is Ignored

Write To Write-Protected Control Register Is Ignored
    Write To ${Control} Is Ignored

Write To Write-Protected Restart Register Is Ignored
    Write To ${Restart} Is Ignored

Write To Write-Protected Control Register Is Allowed After Write-Enable
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Write To ${Control} Is Allowed

Consecutive Writes To Write-Protected Control Register Is Ignored After Write-Enable
    Write Watchdog Word ${ATCWDT200_WP_NUM} To ${WriteEnable}
    Write To ${Control} Is Allowed
    Write To ${Control} Is Ignored  value=0xDE
    Write To ${Control} Is Ignored  value=0xFA

Interrupt Timer Fires After Default Interval
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    Watchdog IRQ Should Initially Be Low And After Timeout Be High

Interrupt Timer Only Fires Once
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    # Timer should fire once.
    Wait For Interrupt Timeout
    Wait For Log Entry              Interrupt timer elapsed

    # Timer should not fire again.
    Wait For Interrupt Timeout
    Should Not Be In Log            Interrupt timer elapsed

Interrupt Signal Does Not Fire When Interrupt Disabled
    # Watchdog interrupt is disabled by default, so we don't have to disable it.

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    Watchdog IRQ Should Initially Be Low And After Timeout Be Low

Interrupt Timer Does Not Fire When Watchdog Disabled
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so we don't have to disable it.

    Watchdog IRQ Should Initially Be Low And After Timeout Be Low

Reset Timer Does Not Fire When Watchdog Disabled
    Enable Watchdog Interrupt
    Enable Watchdog System Reset
    # Watchdog timer is disabled by default, so we don't have to disable it.

    Watchdog IRQ Should Initially Be Low And After Timeout Be Low
    Watchdog System Reset Should Initially Not Be Triggered And After Timeout Not Be Triggered

Reset Timer Fires When Interrupt Signal Disabled
    # Watchdog interrupt is disabled by default, so we don't have to disable it.

    Enable Watchdog System Reset
    Enable Watchdog Timer

    Watchdog IRQ Should Initially Be Low And After Timeout Be Low
    Watchdog System Reset Should Initially Not Be Triggered And After Timeout Be Triggered

Reset Timer Does Not Fire When Reset Signal Disabled
    # Watchdog reset signal is disabled by default, so we don't have to disable it.

    Enable Watchdog Timer

    Watchdog IRQ Should Initially Be Low And After Timeout Be Low
    Watchdog System Reset Should Initially Not Be Triggered And After Timeout Not Be Triggered

Write To Restart Register Restarts Interrupt Timer
    Write ${ATCWDT200_RESTART_NUM} To Restart Register Periodically

    # Watchdog interrupt should not have been triggered, due to the restarting.
    Watchdog IRQ Should Be Low

Writing Invalid Value To Restart Register Does Not Restart Interrupt Timer
    Write 0xdead To Restart Register Periodically

    # Watchdog interrupt should still have been triggered, as the restarting was invalidly done.
    Watchdog IRQ Should Be High

Write To Restart Register Cancels System Reset Timer
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    # Let the interrupt timer elapse, in order to start the reset timer.
    # But don't wait long enough that the reset timer elapses.
    Wait For Interrupt Timeout

    # Interrupt should have now been triggered, starting the reset timer.
    Watchdog IRQ Should Be High

    # Disable the interrupt timer. We don't want it to elapse again,
    # we're just interested in the reset timer.
    Disable Watchdog Interrupt

    # Reset timer should not have elapsed yet.
    Watchdog System Reset Should Not Be Triggered

    # Now, send restart signal in order to cancel the reset timer.
    Restart Watchdog

    # Let enough time pass for the reset timer to elapse, if it wasn't cancelled as it should have been.
    Wait For Reset Timeout

    # Watchdog system reset should not have been triggered, due to the restarting cancelling the timer.
    Watchdog System Reset Should Not Be Triggered

Reset Signal Activates After Interrupt Activates
    Enable Watchdog Interrupt
    Enable Watchdog System Reset
    Enable Watchdog Timer

    # Let the interrupt timer elapse first.
    Watchdog IRQ Should Initially Be Low And After Timeout Be High

    # Then, let the system reset timer elapse.
    Watchdog System Reset Should Initially Not Be Triggered And After Timeout Be Triggered

Reset Does Not Trigger When Disabled
    Enable Watchdog Interrupt
    Enable Watchdog Timer

    # Let the interrupt timer elapse.
    Watchdog IRQ Should Initially Be Low And After Timeout Be High

    # Reset timer shouldn't elapse.
    Watchdog System Reset Should Initially Not Be Triggered And After Timeout Not Be Triggered

Interrupt Status Register Flag Should Always Match Interrupt Signal
    Enable Watchdog Interrupt
    Enable Watchdog Timer

    # Initially, both should be low.
    Interrupt Status Register Flag Matches IRQ Signal

    # Let interrupt timer elapse...
    Wait For Interrupt Timeout

    # After the timeout, they should both be high.
    Interrupt Status Register Flag Matches IRQ Signal

Writing 1 To Interrupt Status Register Flag Should Clear It
    Enable Watchdog Interrupt
    Enable Watchdog Timer

    # Flag should initially be unset.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  0  Interrupt flag should be unset initially

    # Let interrupt timer elapse...
    Wait For Interrupt Timeout

    # Flag should now be set.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  1  Interrupt flag should be unset initially

    # Write 1 to the flag to clear it.
    Set Watchdog Flag At Bit ${InterruptExpired} In ${Status} To 1

    # Flag should now be unset.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  0  Interrupt flag should have been unset by the write

Writing 0 To Interrupt Status Register Flag Should Do Nothing
    Enable Watchdog Interrupt
    Enable Watchdog Timer

    # Flag should initially be unset.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  0  Interrupt flag should be unset initially

    # Let interrupt timer elapse...
    Wait For Interrupt Timeout

    # Flag should now be set.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  1  Interrupt flag should be unset initially

    # Write 0 to the flag.
    Set Watchdog Flag At Bit ${InterruptExpired} In ${Status} To 0

    # Flag should still be set.
    ${interrupt_flag}=              Read Watchdog Flag At Bit ${InterruptExpired} In ${Status}
    Should Be Equal As Integers     ${interrupt_flag}  1  Interrupt flag should remain unchanged after the write

Interrupt Timer Fires Again After Status Is Cleared
    # Watchdog interrupt is disabled by default, so we have to enable it.
    Enable Watchdog Interrupt

    # Watchdog timer is disabled by default, so enable it.
    Enable Watchdog Timer

    # Timer should fire once.
    Wait For Interrupt Timeout
    Wait For Log Entry              Interrupt timer elapsed

    # Clear the status.
    Set Watchdog Flag At Bit ${InterruptExpired} In ${Status} To 1

    # Timer should fire again.
    Wait For Interrupt Timeout
    Wait For Log Entry              Interrupt timer elapsed
