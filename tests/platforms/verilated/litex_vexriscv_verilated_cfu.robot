*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${CFU_BASIC_NATIVE_LINUX}           ${URI}/verilated-ibex--libVtop-s_527064-bf919fbb21bc3242cbc09f05a8a8cac4037daaff
${RESC}                             @scripts/single-node/litex_vexriscv_verilated_cfu.resc
${UART}                             sysbus.uart

*** Keywords ***
Create Machine
    Execute Command                 \$cfuLinux?=${CFU_BASIC_NATIVE_LINUX}
    Execute Command                 i ${RESC}
    Create Terminal Tester          ${UART}

*** Test Case ***
Should Pass Functional HW/SW Compare Tests
    [Tags]                          skip_windows  skip_osx  skip_host_arm
    Create Machine

    Wait For Prompt On UART         main>
    Write To UART                   2
    Wait For Prompt On UART         functional>
    Write To UART                   c
    Wait For Line On UART           Ran 481474 comparisons.
