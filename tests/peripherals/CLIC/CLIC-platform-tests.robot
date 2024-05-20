*** Variables ***
${NRF54L15_UART}              sysbus.uart30
${NRF54L15_BOARD_NAME}        nrf54l15_cpuflpr
${HELLO_WORLD_URI}            @https://dl.antmicro.com/projects/renode/nrf54l15pdk--zephyr-hello_world.elf-s_732140-5c387a1f075e4f48ace7db9af4db6f179d018f1f
${BLINKY_URI}                 @https://dl.antmicro.com/projects/renode/nrf54l15pdk--zephyr-blinky.elf-s_737076-7f9c4161b6b35dad988252e079654e8953fefa66
${TOCKOS_HELLO_URI}               @wip-bins/arty_e21_cxx_hello.elf

${BOARD_NAME}                 nrf54l15pdk@0.2.1/nrf54l15/cpuflpr

*** Keywords ***
Create NRF54L15 Machine
    [Arguments]               ${elf}
    Execute Command           $elf=${elf}
    Execute Script            ${CURDIR}/../../scripts/single-node/nrf54l15_cpuflpr.resc

Create SiFiveE21 Machine
    [Arguments]               ${elf}
    Execute Command           $elf=${elf}
    Execute Script            ${CURDIR}/../../scripts/single-node/arty_sifive_e21.resc

*** Test Cases ***
Should Run Hello World On NRF54L15
    [Tags]                          skipped
    Create NRF54L15 Machine         ${HELLO_WORLD_URI}
    Create Terminal Tester          ${NRF54L15_UART}
    Start Emulation
    Wait For Line On Uart           *** Booting Zephyr OS build
    Wait For Line On Uart           Hello World! ${BOARD_NAME}

Should Run Blinky On NRF54L15
    [Tags]                          skipped
    Create NRF54L15 Machine         ${BLINKY_URI}
    ${led0_tester}=                 Create LED Tester        sysbus.gpio0.led0
    ${led1_tester}=                 Create LED Tester        sysbus.gpio1.led1
    Start Emulation
    Assert LED Is Blinking          testDuration=5  onDuration=0.5  offDuration=0.5  testerId=${led0_tester}
    Assert LED Is Blinking          testDuration=5  onDuration=0.5  offDuration=0.5  testerId=${led1_tester}

Should Run TockOS Hello Example On SiFive E21
    Create SiFiveE21 Machine          ${TOCKOS_HELLO_URI}
    Start Emulation
