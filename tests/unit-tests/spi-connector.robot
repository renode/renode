*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${COUNTERMAX}                  10
${MASTERPLATFORM}              "spim: SPI.SPIMasterModeController @ sysbus 0x00000000"
${SLAVEPLATFORM}               "spis: SPI.SPISlaveModeController @ sysbus 0x00000000"

*** Keywords ***
Create Setup
    Execute Command                 include @${CURDIR}/spi-connector/SPIMasterModeController.cs
    Execute Command                 include @${CURDIR}/spi-connector/SPISlaveModeController.cs

    Execute Command                 emulation CreateSPIConnector "spi-con"

    Execute Command                 mach create "Peripheral"
    Execute Command                 machine LoadPlatformDescriptionFromString ${SLAVEPLATFORM}
    Execute Command                 connector Connect sysbus.spis "spi-con"

    Execute Command                 mach create "Controller"
    Execute Command                 machine LoadPlatformDescriptionFromString ${MASTERPLATFORM}
    Execute Command                 connector Connect sysbus.spim "spi-con"

*** Test Cases ***
Should Communicate With One Packet Delay
    Create Setup
    Create Log Tester               1
    Start Emulation

    ${buffer}=                      Set Variable                    0

    FOR      ${index}      IN RANGE     ${COUNTERMAX}
        Wait For LogEntry               Master sent:${index} received:${buffer}
        Wait For LogEntry               Slave received:${index} sent:${index}
        ${buffer}=                      Set Variable                    ${index}
    END
    Wait For LogEntry               Slave finished transmission

Should Communicate With Two Packet Delay
    Create Setup
    Execute Command                 sysbus.spim SendTwice True
    Create Log Tester               1
    Start Emulation

    ${buffer}=                      Set Variable                    0
    ${buffer2}=                     Set Variable                    0

    FOR      ${index}      IN RANGE     0      ${COUNTERMAX}      2
        ${index_succ}                   Evaluate                        ${index} + 1
        Wait For LogEntry               Master sent:${index} received:${buffer}
        Wait For LogEntry               Master sent:${index_succ} received:${buffer2}
        Wait For LogEntry               Slave received:${index} sent:${index}
        Wait For LogEntry               Slave received:${index_succ} sent:${index_succ}
        ${buffer}=                      Set Variable                    ${index}
        ${buffer2}=                     Set Variable                    ${index_succ}
    END
    Wait For LogEntry               Slave finished transmission
