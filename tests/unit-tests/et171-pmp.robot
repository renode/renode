*** Variables ***
${SCRIPT_PATH}                      @scripts/single-node/egis_et171_zephyr.resc
${UART}                             sysbus.uart0
${MEM_PROTECT_PROTECTION_BIN}       @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-test-mem_protect-protection.elf-s_671524-6052e2520e82ddd6e4e940ff251969600c04c983

*** Keywords ***
Create Machine With Binary ${binary}
    Execute Command                 $bin=${binary}
    Execute Command                 include ${SCRIPT_PATH}

    Create Terminal Tester          ${UART}  timeout=0.1  defaultPauseEmulation=true

*** Test Cases ***
Should Pass Zephyr mem_protect/protection Test Suite On ET171
    Create Machine With Binary ${MEM_PROTECT_PROTECTION_BIN}

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr mem_protect/protection Suite On ET171 After Reset
    Create Machine With Binary ${MEM_PROTECT_PROTECTION_BIN}

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

    # Reset, to check that the PMP state is correctly restored afterwards.
    Execute Command                 machine Reset

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL
