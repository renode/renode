*** Variables ***
${UART}                             sysbus.mmuart1
${URI}                              @https://dl.antmicro.com/projects/renode
${PLATFORM}                         @platforms/cpus/polarfire-soc.repl
${VARIABLE_ADDRESS_CPU1}            0x81000000
${VARIABLE_ADDRESS_CPU2}            0x81000100

# Registers used
${a0}                               10
${a1}                               11
${a2}                               12
${a3}                               13

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus.u54_1 ExecutionMode SingleStep
    Execute Command                 sysbus.u54_2 ExecutionMode SingleStep
    Execute Command                 sysbus.u54_1 PC 0x80000000
    Execute Command                 sysbus.u54_2 PC 0x80000100

Assemble Instruction
    [Arguments]                     ${cpu}  ${mnemonic}  ${operands}=  ${address}=0
    ${len}=                         Execute Command  sysbus.${cpu} AssembleBlock ${address} "${mnemonic} ${operands}"

Create Reservations
    # Just write 5 to memory, we'll use this to check for successful and failed writes
    Execute Command                 sysbus WriteDoubleWord ${VARIABLE_ADDRESS_CPU1} 0x5
    Execute Command                 sysbus WriteDoubleWord ${VARIABLE_ADDRESS_CPU2} 0x5

    # Make a0 hold the memory address

    # li a0, ${VARIABLE_ADDRESS_CPU1} (two instructions)
    Assemble Instruction            u54_1  li  a0, ${VARIABLE_ADDRESS_CPU1}  0x80000000
    Execute Command                 sysbus.u54_1 Step 2
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU1}  cpuName=u54_1

    # li a0, ${VARIABLE_ADDRESS_CPU2} (three instructions)
    Assemble Instruction            u54_2  li  a0, ${VARIABLE_ADDRESS_CPU2}  0x80000100
    Execute Command                 sysbus.u54_2 Step 3
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU2}  cpuName=u54_2

    # Create reservation on first core
    Assemble Instruction            u54_1  lr.d  a1, (a0)  0x80000006
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a1}  0x5  cpuName=u54_1

    # Create reservation on second core
    Assemble Instruction            u54_2  lr.d  a1, (a0)  0x8000010A
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a1}  0x5  cpuName=u54_2

*** Test Cases ***
Should Handle Multiple Writes To Same Reservation
    Create Machine
    Create Reservations

    # Try to update memory address with number 6
    # This will check if simple LR/SC behaves correctly

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    # Check for successful SC
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x8000000C
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_1

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
    Should Be Equal As Integers     ${res}  6

    # Try to SC on something that isn't reserved - this should fail (returns 1)

    Assemble Instruction            u54_1  sc.d  a3, zero, (a0)  0x80000010
    Execute Command                 sysbus.u54_1 Step

    # Check if SC failed (correct behavior)
    Register Should Be Equal        ${a3}  0x1  cpuName=u54_1

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
    Should Be Equal As Integers     ${res}  0x00000006

Should Work On Multiple Cores
    Create Machine
    Create Reservations

    # Having reservations on two cores, we try to store on both of them

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    Assemble Instruction            u54_2  li  a2, 0x7  0x8000010E
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a2}  0x7  cpuName=u54_2

    # Check for successful store on second core
    Assemble Instruction            u54_2  sc.d  a3, a2, (a0)  0x80000110
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_2

    # Check for successful store on first core
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x8000000C
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_1

Should Drop Other Core Reservation On SC
    Create Machine
    Create Reservations

    # Check if SC on other core's LR will drop the reservation

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    # Get the address of second core's reservation to first core's a0
    Assemble Instruction            u54_1  li  a0, ${VARIABLE_ADDRESS_CPU2}  0x8000000C
    Execute Command                 sysbus.u54_1 Step 3
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU2}  cpuName=u54_1

    # Try to store on second core's reservation
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x80000016
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x1  cpuName=u54_1

    # Try to store on second core's reservation by second core
    Assemble Instruction            u54_2  sc.d  a3, a2, (a0)  0x80000110
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_2
