*** Variables ***
${PROGRAM_COUNTER}                  0x80000000
${PIT_ADDRESS}                      0xf0400000
${CH0_CTRL_OFFSET}                  0x20
${CH0_RELOAD_OFFSET}                0x24
${INTERRUPT_ENABLE_OFFSET}          0x14
${CH_ENABLE_OFFSET}                 0x1C
${INTERRUPT_STATE_OFFSET}           0x18
${CHANNEL_STEP}                     0x10
*** Keywords ***
Create Machine
    Execute Command                 include @platforms/cpus/egis_et171.repl
    Execute Command                 cpu0 PC ${PROGRAM_COUNTER}
    Create Log Tester               0

Channel ${number:(0|1|2|3)} ${interrupt_enable:(Should|Should Not)} Fire And Clear Interrupt In Single 32-bit Mode
    Create Machine
    Execute Command                 logLevel -1

    ${ctrl_offset}=  Evaluate       ${CH0_CTRL_OFFSET} + (${number} * ${CHANNEL_STEP})
    ${reload_offset}=  Evaluate     ${CH0_RELOAD_OFFSET} + (${number} * ${CHANNEL_STEP})
    ${channel_bit}=  Evaluate       1 << (${number} * 4)
    ${interrupt_bit}=  Evaluate     ${channel_bit} if "${interrupt_enable}" == "Should" else 0
    ${frequency}=  Execute Command  syscon APBClockFrequency
    ${delay}=  Evaluate             int(${frequency} / 10) #delay of 0.1 second

    ${PROG}=  Catenate              SEPARATOR=\n
    ...                             li a0, ${PIT_ADDRESS}
    ...                             li t0, 1  # 32-bit timer mode
    ...                             sw t0, ${ctrl_offset}(a0)
    ...                             li t0, ${delay}
    ...                             sw t0, ${reload_offset}(a0)
    ...                             li t0, ${interrupt_bit}
    ...                             sw t0, ${INTERRUPT_ENABLE_OFFSET}(a0)
    ...                             li t0, ${channel_bit}
    ...                             sw t0, ${CH_ENABLE_OFFSET}(a0)
    ...                             loop:
    ...                             j loop

    Execute Command                 cpu0 AssembleBlock ${PROGRAM_COUNTER} """${PROG}"""

    Execute Command                 emulation RunFor "0.1001"

    Wait For Log Entry              pit0: Channel ${number} timer 0 fired
    IF  $interrupt_enable == "Should"
        Wait For Log Entry              pit0: Setting IRQ to True
        Wait For Log Entry              plic: Setting GPIO number #22 to value True
        Wait For Log Entry              plic: Setting state to True for source #22

        # Write 1 to interrupt state to clear the interrupt
        ${PROG}=  Catenate              SEPARATOR=\n
        ...                             li t0, ${interrupt_bit}
        ...                             sw t0, ${INTERRUPT_STATE_OFFSET}(a0)
        ...                             loop: 
        ...                             j loop

        Execute Command                 cpu0 AssembleBlock `cpu0 PC` """${PROG}"""
        Execute Command                 emulation RunFor "0.001"
        Wait For Log Entry              pit0: Setting IRQ to False
    ELSE
        Should Not Be In Log            pit0: Setting IRQ to True
        Should Not Be In Log            plic: Setting GPIO number #22 to value True
        Should Not Be In Log            plic: Setting state to True for source #22
    END

    Reset Emulation

*** Test Cases ***
PIT Should Fire Interrupts Correctly In 32-bit Mode
    [Template]  Channel ${number:(0|1|2|3)} ${interupt_enable:(Should|Should Not)} Fire And Clear Interrupt In Single 32-bit Mode
    FOR  ${channel}  IN  0  1  2  3
        FOR  ${interrupt_enable}  IN  Should  Should Not
            ${channel}  ${interrupt_enable}
        END
    END
