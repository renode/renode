*** Settings ***
Test Timeout             2 minutes


*** Variables ***
${URI}                   @https://dl.antmicro.com/projects/renode


*** Keywords ***
Create Machine
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @platforms/cpus/sifive-fu540.repl

    Execute Command             sysbus LoadELF ${URI}/hifive-unleashed--bbl.elf-s_17219640-c7e1b920bf81be4062f467d9ecf689dbf7f29c7a
    Execute Command             sysbus LoadFdt ${URI}/hifive-unleashed--devicetree.dtb-s_10532-70cd4fc9f3b4df929eba6e6f22d02e6ce4c17bd1 0x81000000 "earlyconsole mem=256M@0x80000000"
    Execute Command             e51 SetRegisterUnsafe 11 0x81000000

    Execute Command             u54_1 ExecutionMode SingleStepNonBlocking

    Create Terminal Tester      sysbus.uart0

*** Test Cases ***
Should Start Execution With One Core In SingleStepNonBlocking
    Create Machine
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs


Should Step Core In SingleStepNonBlocking
    Create Machine
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs

    ${x}=  Execute Command      u54_1 PC
    Should Contain              ${x}  0x80000000

    Execute Command             u54_1 Step

    ${x}=  Execute Command      u54_1 PC
    Should Contain              ${x}  0x800001f8


Should Step Core In SingleStepNonBlocking Over Quantum Limit
    Create Machine
    Execute Command             u54_1 PerformanceInMips 1
    Execute Command             machine SetQuantum "00:00:00.000100"
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs

    # InstructionsPerQuantum = MIPS * Quantum =  10^6 * 10^-4 = 100  
    # Every Quant (time allowance) will consist of a maximum of 100 instructions
    # Thereby stepping by 101 steps, guarantees that the next Quantum will need to be given

    ${x}=  Execute Command      u54_1 Step 101
    Should Contain              ${x}  0x0000000080001C1C