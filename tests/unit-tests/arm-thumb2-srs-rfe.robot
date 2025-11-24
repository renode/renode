*** Settings ***
Test Setup                          Create Machine

*** Variables ***
${SRS_ASSEMBLY}                     SEPARATOR=\n
...                                 blx switch_to_thumb  # `blx label` changes the instruction set from A32/T32 to T32/A32.
...                                 switch_to_thumb:
...                                 .thumb
...                                 srsdb sp, #1

${RFE_ASSEMBLY}                     SEPARATOR=\n
...                                 msr cpsr_c, #0x12  # Switch to IRQ ARM processor mode
...                                 blx switch_to_thumb  # `blx label` changes the instruction set from A32/T32 to T32/A32.
...                                 switch_to_thumb:
...                                 .thumb
...                                 rfeia r10

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create "arm-thumb"

    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command                 machine LoadPlatformDescriptionFromString "ram: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command                 cpu PC 0x0

*** Test Cases ***
# These should execute without crashing Renode.
Should Not Encounter Invalid TCG Variable When Executing SRS In Thumb Mode
    Execute Command                 cpu AssembleBlock 0x0 "${SRS_ASSEMBLY}"
    Execute Command                 cpu Step 2  # Execute SRS instruction in Thumb mode

Should Not Encounter Invalid TCG Variable When Executing RFE In Thumb Mode
    Execute Command                 cpu PC 0x0
    Execute Command                 cpu AssembleBlock 0x0 "${RFE_ASSEMBLY}"
    Execute Command                 cpu Step 3  # Execute RFE instruction in Thumb mode
