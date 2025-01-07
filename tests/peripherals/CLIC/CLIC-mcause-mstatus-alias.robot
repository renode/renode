*** Variables ***
${starting_pc}                      0x80000000

# Set CLIC mode in MTVEC
# and write to MSTATUS to check if bits are mirrored in MCAUSE
# needs to put desired value to A0 beforehand
${PROG_MSTATUS}                     SEPARATOR=\n
...                                 csrrsi x0, mtvec, 0x3
...                                 csrrw x0, MSTATUS, a0
...                                 j .

# Set CLIC mode in MTVEC
# and write to MCAUSE to check if bits are mirrored in MSTATUS
# needs to put desired value to A1 beforehand
${PROG_MCAUSE}                      SEPARATOR=\n
...                                 csrrsi x0, mtvec, 0x3
...                                 csrrw x0, MCAUSE, a1
...                                 j .

# Same as above, but CLINT mode, so bits should not be mirrored
${PROG_MCAUSE_CLINT}                SEPARATOR=\n
...                                 csrrsi x0, mtvec, 0x1
...                                 csrrw x0, MCAUSE, a1
...                                 j .

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 using sysbus
    Execute Command                 machine LoadPlatformDescription @tests/peripherals/CLIC/CLIC-test-platform.repl
    Execute Command                 cpu PC ${starting_pc}

*** Test Cases ***
MSTATUS should mirror MCAUSE MPP and MPIE in CLIC mode
    Create Machine
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG_MSTATUS}"
    Execute Command                 sysbus.cpu SetRegister "A0" 0x1880
    Execute Command                 sysbus.cpu Step 3
    ${mcause}=                      Execute Command  sysbus.cpu MCAUSE
    Should Be Equal As Integers     ${mcause}  0x38000000

MCAUSE should mirror MSTATUS MPP and MPIE in CLIC mode
    Create Machine
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG_MCAUSE}"
    Execute Command                 sysbus.cpu SetRegister "A1" 0x8000000
    Execute Command                 sysbus.cpu Step 3
    ${mstatus}=                     Execute Command  sysbus.cpu MSTATUS
    Should Be Equal As Integers     ${mstatus}  0x80

MCAUSE should not mirror MSTATUS MPP and MPIE in CLIC mode on invalid mode write
    Create Machine
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG_MCAUSE}"
    # Unsupported value (0b10) written to MPP in MCAUSE - should keep the old value instead, as MSTATUS won't allow it
    Execute Command                 sysbus.cpu SetRegister "A1" 0x28000000
    Execute Command                 sysbus.cpu Step 3
    ${mstatus}=                     Execute Command  sysbus.cpu MSTATUS
    Should Be Equal As Integers     ${mstatus}  0x1880

MCAUSE should not mirror MSTATUS MPP and MPIE in CLINT mode
    Create Machine
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG_MCAUSE_CLINT}"
    Execute Command                 sysbus.cpu SetRegister "A1" 0x0
    Execute Command                 sysbus.cpu Step 3
    ${mstatus}=                     Execute Command  sysbus.cpu MSTATUS
    Should Be Equal As Integers     ${mstatus}  0x1800
