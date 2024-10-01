*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${MSP430F2619_HELLO_WORLD_ELF}      ${URI}/msp430f2619-hello_world.elf-s_7912-e951b1bdd3bb562397ca9da8da88722c503507a3

*** Keywords ***
Create MSP430F2619 Machine
    [Arguments]                             ${ELF}

    Execute Command                         mach create
    Execute Command                         machine LoadPlatformDescription @platforms/cpus/msp430f2619.repl
    Execute Command                         sysbus.cpu PerformanceInMips 1
    Execute Command                         sysbus LoadELF ${ELF}

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
