*** Variables ***
${PLATFORM}                   @platforms/boards/nrf54l15_cpuflpr.repl
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/nrf54l15_cpuflpr.resc

${UART}                       sysbus.uart30
${HELLO_WORLD_URI}            @https://dl.antmicro.com/projects/renode/nrf54l15pdk--zephyr-hello_world.elf-s_732140-5c387a1f075e4f48ace7db9af4db6f179d018f1f
${BLINKY_URI}                 @https://dl.antmicro.com/projects/renode/nrf54l15pdk--zephyr-blinky.elf-s_737076-7f9c4161b6b35dad988252e079654e8953fefa66

${BOARD_NAME}                 nrf54l15pdk@0.2.1/nrf54l15/cpuflpr

*** Keywords ***
Create Machine
    [Arguments]               ${elf}
    Execute Command           $elf=${elf}
    Execute Script            ${SCRIPT}

*** Test Cases ***
Should Run Hello World
    [Tags]                          skipped
    Create Machine                  ${HELLO_WORLD_URI}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           *** Booting Zephyr OS build
    Wait For Line On Uart           Hello World! ${BOARD_NAME}

Should Run Blinky
    [Tags]                          skipped
    Create Machine                  ${BLINKY_URI}
    ${led0_tester}=                 Create LED Tester        sysbus.gpio0.led0
    ${led1_tester}=                 Create LED Tester        sysbus.gpio1.led1
    Start Emulation
    Assert LED Is Blinking          testDuration=5  onDuration=0.5  offDuration=0.5  testerId=${led0_tester}
    Assert LED Is Blinking          testDuration=5  onDuration=0.5  offDuration=0.5  testerId=${led1_tester}

