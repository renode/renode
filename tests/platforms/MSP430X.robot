*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${MSP430F2619_HELLO_WORLD_ELF}      ${URI}/msp430f2619-hello_world.elf-s_7912-e951b1bdd3bb562397ca9da8da88722c503507a3

*** Keywords ***
Create MSP430F2619 Machine
    [Arguments]                             ${ELF}=${EMPTY}

    Execute Command                         mach create
    Execute Command                         machine LoadPlatformDescription @platforms/cpus/msp430f2619.repl
    Execute Command                         sysbus.cpu PerformanceInMips 1
    Run Keyword If                          "${ELF}" != "${EMPTY}"
    ...  Execute Command                    sysbus LoadELF ${ELF}

*** Test Cases ***
Should Change Internal Memory Every Second
    Create MSP430F2619 Machine              ${MSP430F2619_HELLO_WORLD_ELF}
    ${counterAddress}=  Execute Command     sysbus GetSymbolAddress "seconds_passed"

    Execute Command                         emulation RunFor "0.05"
    ${secondsPassed}=   Execute Command     sysbus ReadWord ${counterAddress}
    Should Be Equal     ${secondsPassed}    0x0000    strip_spaces=True

    FOR  ${second}  IN RANGE  1  10
        ${secondHex}=       Convert To Hex      ${second}  prefix=0x  length=4
        Execute Command                         emulation RunFor "1"
        ${secondsPassed}=   Execute Command     sysbus ReadWord ${counterAddress}
        Should Be Equal     ${secondsPassed}    ${secondHex}    strip_spaces=True
   END

Should Correctly Handle Constant Generators In ADDA And SUBA
    Create MSP430F2619 Machine

    # NOTE: Prepare small program using ADDA and SUBA with CG1/CG2
    Execute Command                         sysbus WriteWord 0x2100 0x02e4  # asm: ADDA R2, R4
    Execute Command                         sysbus WriteWord 0x2102 0x03e4  # asm: ADDA R3, R4
    Execute Command                         sysbus WriteWord 0x2104 0x02f4  # asm: SUBA R2, R4
    Execute Command                         sysbus WriteWord 0x2106 0x03f4  # asm: SUBA R3, R4
    Execute Command                         cpu PC 0x2100

    # NOTE: Start with zeroed R4
    Execute Command                         cpu R4 0x00000

    # NOTE: ADDA R2, R4 ==> ADDA #4, R4
    Execute Command                         cpu Step
    ${REG_VALUE}=  Execute Command          cpu R4
    ${REG_VALUE}=  Convert To Integer       ${REG_VALUE}  base=16
    Should Be Equal                         ${REG_VALUE}  ${4}

    # NOTE: ADDA R3, R4 ==> ADDA #2, R4
    Execute Command                         cpu Step
    ${REG_VALUE}=  Execute Command          cpu R4
    ${REG_VALUE}=  Convert To Integer       ${REG_VALUE}  base=16
    Should Be Equal                         ${REG_VALUE}  ${6}

    # NOTE: SUBA R2, R4 ==> SUBA #4, R4
    Execute Command                         cpu Step
    ${REG_VALUE}=  Execute Command          cpu R4
    ${REG_VALUE}=  Convert To Integer       ${REG_VALUE}  base=16
    Should Be Equal                         ${REG_VALUE}  ${2}

    # NOTE: SUBA R3, R4 ==> SUBA #2, R4
    Execute Command                         cpu Step
    ${REG_VALUE}=  Execute Command          cpu R4
    ${REG_VALUE}=  Convert To Integer       ${REG_VALUE}  base=16
    Should Be Equal                         ${REG_VALUE}  ${0}
