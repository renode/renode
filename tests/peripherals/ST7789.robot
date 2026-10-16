*** Settings ***
Test Setup              Create Machine


*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode/
${SCREEN_DEVICE}        spi2.screen
${FB_TESTER_NAME}       fb_tester
${TIMEOUT}              10

# SPI commands
${CASET}                0x2a
${RASET}                0x2b
@{ADDR_SET}             0xff  0x00  0xff  0xff


*** Keywords ***
Create Machine
    Test Setup  # Renode's test setup from renode-keywords.robot
    Execute Command     include @platforms/boards/ramn.repl
    Execute Command     include @platforms/boards/ramn/GATEWAY.repl
    Execute Command     sysbus LoadELF @${URL}/RAMN_screen_vscroll.elf-s_2355120-54e5fae6722d72db3ae66c77ef43be3f6331521b

    Execute Command     emulation CreateFrameBufferTester "${FB_TESTER_NAME}" ${TIMEOUT}
    Execute Command     ${FB_TESTER_NAME} AttachTo sysbus.spi2.screen

    Create Log Tester   0

Send Command
    [Arguments]         ${command}     ${arguments}

    Execute Command     ${SCREEN_DEVICE} OnGPIO 0 false     # DCX line moved to command mode
    Execute Command     ${SCREEN_DEVICE} Transmit ${command}

    Execute Command     ${SCREEN_DEVICE} OnGPIO 0 true      # DCX line moved to data mode
    FOR     ${arg}   IN     @{arguments}
        Execute Command     ${SCREEN_DEVICE} Transmit ${arg}
    END


*** Test Cases ***
Scroll Area Should Move On Scroll Start Address Increment
    Execute Command         fb_tester WaitForFrame @${URL}/st7789-vscroll-init.png-s_1409-18707664154b0cf5e7fc432cc17dd4f96b8cebe7
    Execute Command         fb_tester WaitForFrame @${URL}/st7789-vscroll-scrolled.png-s_1421-a7c51bb5cfb9363abd57c31508a7c87651b2fd4e

    Should Not Be In Log    ${SCREEN_DEVICE}    level=Error
    Should Not Be In Log    ${SCREEN_DEVICE}    level=Warning

Invalid Address Set Should Be Ignored
    Send Command    ${CASET}    ${ADDR_SET}
    Wait For Log Entry      Invalid (XS, XE) (65280, 65535)

    Send Command    ${RASET}    ${ADDR_SET}
    Wait For Log Entry      Invalid (YS, YE) (65280, 65535)

    # Let's run the firmware for ${TIMEOUT} seconds to be sure that model is working as expected
    Should Not Be In Log    ${SCREEN_DEVICE}    level=Error     timeout=${TIMEOUT}
    Should Not Be In Log    ${SCREEN_DEVICE}    level=Warning   timeout=0
