*** Settings ***
Test Setup         Create Machine
*** Variables ***
${CODE_BASE_ADDRESS}                0x8000000
${TCM_A_VALUE}                      0x12121212
${TCM_B_VALUE}                      0x34343434
${TCM_C_VALUE}                      0x56565656

${PLAT}                             SEPARATOR=\n  """
...                                 cpu: CPU.ARMv8R @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-r52"
...                                 ${SPACE*4}genericInterruptController: gic
...                                 ${SPACE*4}init:
...                                 ${SPACE*4}${SPACE*4}RegisterTCMRegion sysbus.atcm0 0
...                                 ${SPACE*4}${SPACE*4}RegisterTCMRegion sysbus.btcm0 1
...                                 ${SPACE*4}${SPACE*4}RegisterTCMRegion sysbus.ctcm0 2
...
...                                 timer: Timers.ARM_GenericTimer @ cpu
...                                 ${SPACE*4}frequency: 1000000000
...                                 ${SPACE*4}EL1PhysicalTimerIRQ -> gic#0@30
...                                 ${SPACE*4}EL1VirtualTimerIRQ -> gic#0@27
...                                 ${SPACE*4}NonSecureEL2PhysicalTimerIRQ -> gic#0@26
...
...                                 gic: IRQControllers.ARM_GenericInterruptController @ {
...                                 ${SPACE*4}${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0x6E00000; size: 0x10000; region: \"distributor\" };
...                                 ${SPACE*4}${SPACE*4}sysbus new IRQControllers.ArmGicRedistributorRegistration { attachedCPU: cpu; address: 0x6E10000 }
...                                 ${SPACE*4}}
...                                 ${SPACE*4}\[0-1] -> cpu@[0-1]
...                                 ${SPACE*4}supportsTwoSecurityStates: false
...
...                                 code: Memory.MappedMemory @ sysbus ${CODE_BASE_ADDRESS}
...                                 ${SPACE*4}size: 0x10000
...
...                                 atcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x0; cpu: cpu }}
...                                 ${SPACE*4}size: 0x10000
...                                 ${SPACE*4}init:
...                                 ${SPACE*4}${SPACE*4}FillWithRepeatingData [${TCM_A_VALUE}] // NB. the value gets truncated to a byte here
...
...                                 btcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x20000; cpu: cpu }}
...                                 ${SPACE*4}size: 0x20000
...                                 ${SPACE*4}init:
...                                 ${SPACE*4}${SPACE*4}FillWithRepeatingData [${TCM_B_VALUE}]
...
...                                 ctcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x40000; cpu: cpu }}
...                                 ${SPACE*4}size: 0x40000
...                                 ${SPACE*4}init:
...                                 ${SPACE*4}${SPACE*4}FillWithRepeatingData [${TCM_C_VALUE}]
...                                 """

${NEW_TCM_A_ADDRESS}                0x60000
${NEW_TCM_B_ADDRESS}                0x00000
${NEW_TCM_C_ADDRESS}                0x20000

${TCM_TEST_ASSEMBLY}                SEPARATOR=\n  """
...                                 // Store mask in R2
...                                 MOV r2, 0x1fff
...
...                                 // Move TCM A to ${NEW_TCM_A_ADDRESS}
...                                 MRC p15, 0, r0, c9, c1, 0
...                                 AND r0, r2
...                                 MOV r1, ${NEW_TCM_A_ADDRESS}
...                                 ORR r0, r1, LSL #13
...                                 MCR p15, 0, r0, c9, c1, 0
...
...                                 // Move TCM B to ${NEW_TCM_B_ADDRESS}
...                                 MRC p15, 0, r0, c9, c1, 1
...                                 AND r0, r2
...                                 MOV r1, ${NEW_TCM_B_ADDRESS}
...                                 ORR r0, r1, LSL #13
...                                 MCR p15, 0, r0, c9, c1, 1
...
...                                 // Move TCM C to ${NEW_TCM_C_ADDRESS}
...                                 MRC p15, 0, r0, c9, c1, 2
...                                 AND r0, r2
...                                 MOV r1, ${NEW_TCM_C_ADDRESS}
...                                 ORR r0, r1, LSL #13
...                                 MCR p15, 0, r0, c9, c1, 2
...
...                                 // Read values to registers
...                                 MOV r0, ${NEW_TCM_A_ADDRESS}
...                                 LDR r0, [r0] // ${TCM_A_VALUE}
...                                 MOV r1, ${NEW_TCM_B_ADDRESS}
...                                 LDR r1, [r1] // ${TCM_B_VALUE}
...                                 MOV r2, ${NEW_TCM_C_ADDRESS}
...                                 LDR r2, [r2] // ${TCM_C_VALUE}
...
...                                 // Loop indefinitely
...                                 B .
...                                 """

${R0_REGISTER_INDEX}                100
${R1_REGISTER_INDEX}                101
${R2_REGISTER_INDEX}                102

*** Keywords ***
Get System Register As Int
    [Arguments]                     ${reg_name}
    ${as_str}=                      Execute Command  cpu GetSystemRegisterValue ${reg_name}
    ${as_int}=                      Convert To Integer  ${as_str}
    RETURN                          ${as_int}

Get Register Field
    [Arguments]                     ${int_value}  ${start_offset}  ${mask}
    ${field_val}=                   Evaluate  ((${int_value} >> ${start_offset}) & ${mask})
    RETURN                          ${field_val}

Field Should Have Correct Value
    [Arguments]                     ${register_name}  ${field_offset}  ${field_mask}  ${expected_value}  ${error_message}
    ${reg_value}=                   Get System Register As Int  ${register_name}
    ${field_value}=                 Get Register Field  ${reg_value}  ${field_offset}  ${field_mask}
    Should Be Equal As Integers     ${field_value}  ${expected_value}  ${error_message}

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLAT}
    Execute Command                 using sysbus

*** Test Cases ***
# TCM tests
ID_MMFR0 Register Should Have Correct Value
   [Template]   Field Should Have Correct Value
   "ID_MMFR0"  16  0b1111   0b0001  ID_MMFR0 TCM bit should be enabled

TCMType Register Should Have Correct Value
   [Template]   Field Should Have Correct Value
   "TCMTR"  0   0b111   0b111  ABC enabled region bits incorrect
   "TCMTR"  29  0b1111  0b100  TCM bits incorrect

IMP_.TCMREGIONR Should Have Correct Value
   [Template]   Field Should Have Correct Value
   "IMP_ATCMREGIONR"  2  0b11111     0b00111  TCM A region size mismatch
   "IMP_ATCMREGIONR"  0  0xFFFFF000  0x0      TCM A region base address mismatch
   "IMP_BTCMREGIONR"  2  0b11111     0b01000  TCM B region size mismatch
   "IMP_BTCMREGIONR"  0  0xFFFFF000  0x20000  TCM B region base address mismatch
   "IMP_CTCMREGIONR"  2  0b11111     0b01001  TCM C region size mismatch
   "IMP_CTCMREGIONR"  0  0xFFFFF000  0x40000  TCM C region base address mismatch

Should Remap TCM Regions
    Execute Command                 cpu AssembleBlock ${CODE_BASE_ADDRESS} ${TCM_TEST_ASSEMBLY}
    Execute Command                 cpu PC ${CODE_BASE_ADDRESS}
    Execute Command                 emulation RunFor "0.01"

    Register Should Be Equal        ${R0_REGISTER_INDEX}  ${TCM_A_VALUE}
    Register Should Be Equal        ${R1_REGISTER_INDEX}  ${TCM_B_VALUE}
    Register Should Be Equal        ${R2_REGISTER_INDEX}  ${TCM_C_VALUE}
