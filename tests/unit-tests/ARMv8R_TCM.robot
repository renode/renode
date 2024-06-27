*** Settings ***
Test Setup         Create Machine
*** Variables ***
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
...                                 atcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x0; cpu: cpu }}
...                                 ${SPACE*4}size: 0x10000
...
...                                 btcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x20000; cpu: cpu }}
...                                 ${SPACE*4}size: 0x20000
...
...                                 ctcm0: Memory.MappedMemory @ {sysbus new Bus.BusPointRegistration { address: 0x40000; cpu: cpu }}
...                                 ${SPACE*4}size: 0x40000
...                                 """

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
