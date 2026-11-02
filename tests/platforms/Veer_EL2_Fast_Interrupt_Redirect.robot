*** Variables ***
${MACHINE_EXTERNAL_INTERRUPT_INDEX}             11
${EXTERNAL_ISR_ADDRESS}                         0x20000
${UNEXPECTED_ISR_ADDRESS}                       0x29000
${PIC_IRQ_SOURCE_COUNT}                         63
${MACHINE_EXTERNAL_IRQ_VECTOR_TABLE_ADDRESS}    0x22000
${INIT_ADDRESS}                                 0x28000
${PIC_BASE_ADDRESS}                             0xE0000000
${PIC_IRQ_SRC_ENABLE_BASE}                      ${PIC_BASE_ADDRESS}+0x2000
${meihap}                                       0xFC8
${meivt}                                        0xBC8
${meipt}                                        0xBC9
${A1}                                           11

${PLATFORM}                                     SEPARATOR=\n
...                                             cpu: CPU.VeeR_EL2 @ sysbus
...
...                                             pic: IRQControllers.VeeR_EL2_PIC @ sysbus ${PIC_BASE_ADDRESS}
...                                             ${SPACE*4}cpu: cpu
...                                             ${SPACE*4}interruptSourcesCount: ${PIC_IRQ_SOURCE_COUNT}
...                                             ${SPACE*4}->cpu@${MACHINE_EXTERNAL_INTERRUPT_INDEX}
...                                             ${SPACE*4}fastInterruptRedirect: true
...
...                                             memory: Memory.MappedMemory @ sysbus 0x20000
...                                             ${SPACE*4}size: 0x10000

${ISR_CODE}                                     SEPARATOR=\n
#                                               save claimId in register a1
...                                             csrr a1, ${meihap}
...                                             srai a1, a1, 2
...                                             andi a1, a1, 0b111111
...                                             mret

${INIT_CODE}                                    SEPARATOR=\n
...                                             li t0, ${MACHINE_EXTERNAL_IRQ_VECTOR_TABLE_ADDRESS}
...                                             csrw ${meivt}, t0
...                                             csrwi ${meipt}, 0
...                                             li t0, 0x29000
...                                             csrw mtvec, t0
...                                             li t0, 0x800
...                                             csrw mie, t0
...                                             csrsi mstatus, 8
...                                             loop: j loop

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM}"""

    Execute Command                 cpu PC ${INIT_ADDRESS}

    # Fill MEIVT Entries
    FOR  ${meivt_entry}  IN RANGE  ${MACHINE_EXTERNAL_IRQ_VECTOR_TABLE_ADDRESS}  ${MACHINE_EXTERNAL_IRQ_VECTOR_TABLE_ADDRESS} + ${PIC_IRQ_SOURCE_COUNT}*4  4
        Execute Command                 sysbus WriteDoubleWord ${meivt_entry} ${EXTERNAL_ISR_ADDRESS}
    END

    # Enable PIC IRQs
    FOR  ${interrupt_source_enable}  IN RANGE  ${PIC_IRQ_SRC_ENABLE_BASE}  ${PIC_IRQ_SRC_ENABLE_BASE} + ${PIC_IRQ_SOURCE_COUNT}*4  4
        Execute Command                 sysbus WriteDoubleWord ${interrupt_source_enable} 1
    END

    Execute Command                 cpu AssembleBlock ${INIT_ADDRESS} """${INIT_CODE}"""
    Execute Command                 cpu AssembleBlock ${EXTERNAL_ISR_ADDRESS} """${ISR_CODE}"""
    Execute Command                 cpu AddHook ${UNEXPECTED_ISR_ADDRESS} "cpu.ErrorLog('Veer EL2 perfomed an mtvec lookup, but external IRQs are redirected via the PIC fast interrupt mechanism')"
    Execute Command                 emulation RunFor "0.00001"

Test External ISR
    [Arguments]                     ${PIC_IRQ_NUMBER}
    Execute Command                 cpu SetRegister ${A1} 0
    Execute Command                 pic OnGPIO ${PIC_IRQ_NUMBER} true
    Execute Command                 emulation RunFor "0.00001"
    Execute Command                 pic OnGPIO ${PIC_IRQ_NUMBER} false

    Register Should Be Equal        ${A1}  ${${PIC_IRQ_NUMBER}}

*** Test Cases ***
Test External ISRs
    Create Machine
    FOR  ${external_irq}  IN RANGE  1  ${PIC_IRQ_SOURCE_COUNT}
        Test External ISR               ${external_irq}
    END
