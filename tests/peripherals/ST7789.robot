*** Settings ***
Test Setup              Create Machine


*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode/
${SCREEN_DEVICE}        spi2.screen
${FB_TESTER_NAME}       fb_tester
${TIMEOUT}              10


*** Keywords ***
Create Machine
    Test Setup  # Renode's test setup from renode-keywords.robot
    Execute Command     include @platforms/boards/ramn.repl
    Execute Command     include @platforms/boards/ramn/GATEWAY.repl
    Execute Command     sysbus LoadELF @${URL}/RAMN_screen_vscroll.elf-s_2355120-54e5fae6722d72db3ae66c77ef43be3f6331521b

    Execute Command     emulation CreateFrameBufferTester "${FB_TESTER_NAME}" ${TIMEOUT}
    Execute Command     ${FB_TESTER_NAME} AttachTo sysbus.spi2.screen

    Create Log Tester   0


*** Test Cases ***
Scroll Area Should Move On Scroll Start Address Increment
    Execute Command         fb_tester WaitForFrame @${URL}/st7789-vscroll-init.png-s_1409-18707664154b0cf5e7fc432cc17dd4f96b8cebe7
    Execute Command         fb_tester WaitForFrame @${URL}/st7789-vscroll-scrolled.png-s_1421-a7c51bb5cfb9363abd57c31508a7c87651b2fd4e

    Should Not Be In Log    ${SCREEN_DEVICE}    level=Error
    Should Not Be In Log    ${SCREEN_DEVICE}    level=Warning
