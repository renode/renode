*** Variables ***
${CR_REG}                      0x0
${CNT_REG}                     0x4
${CH0_CR}                      0x10
${CH0_IR}                      0x14
${CH0_CMP}                     0x18

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 emulation SetGlobalAdvanceImmediately True
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/nxp-s32k388.repl
    Execute Command                 logLevel -1 stm0
    # These tests do not use the CPU's, so halt them for performance
    Execute Command                 cpu0 IsHalted True
    Execute Command                 cpu1 IsHalted True
    Execute Command                 cpu2 IsHalted True
    Execute Command                 cpu3 IsHalted True

IRQ Should Be Equal
    [Arguments]         ${value}
    ${irq}=  Execute Command        stm0 IRQ IsSet
    Should Contain                  ${irq}  ${value}

*** Test Cases ***
Should Count Up At Correct Speed
    Create Machine
    Execute Command                 stm0 WriteDoubleWord ${CR_REG} 0x1
    Execute Command                 emulation RunFor "0.01"
    # STM runs at 48Mhz
    ${count}=  Execute Command      stm0 ReadDoubleWord ${CNT_REG}
    Should Be Equal As Numbers      ${count}  480_000

Should Trigger Interrupt At Correct Time
    Create Machine
    Execute Command                 stm0 WriteDoubleWord ${CR_REG} 0x1
    Execute Command                 stm0 WriteDoubleWord ${CH0_CMP} 480000
    Execute Command                 stm0 WriteDoubleWord ${CH0_CR} 0x1

    Execute Command                 emulation RunFor "0.005"
    IRQ Should Be Equal             False

    Execute Command                 emulation RunFor "0.005"
    IRQ Should Be Equal             True

Should Trigger Interrupt After Rollover
    Create Machine
    # Set base count 0.01 seconds before rollover
    Execute Command                 stm0 WriteDoubleWord ${CNT_REG} 0xFFF8ACFF
    Execute Command                 stm0 WriteDoubleWord ${CR_REG} 0x1
    Execute Command                 stm0 WriteDoubleWord ${CH0_CMP} 480000
    Execute Command                 stm0 WriteDoubleWord ${CH0_CR} 0x1

    Execute Command                 emulation RunFor "0.01"
    ${count}=  Execute Command      stm0 ReadDoubleWord ${CNT_REG}
    Should Be Equal As Numbers      ${count}  0
    IRQ Should Be Equal             False

    Execute Command                 emulation RunFor "0.01"
    IRQ Should Be Equal             True
