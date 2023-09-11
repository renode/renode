*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode

${ZEPHYR_HELLO_WORLD_ELF}           ${URI}/nucleo_l552ze_q_ns--zephyr--hello_world.elf-s_615516-3e800e15d4386afba85b76c503f452dbc513028d
${ZEPHYR_PROTECTION_ELF}            ${URI}/nucleo_l552ze_q_ns--zephyr--protection.elf-s_730016-68ff84b16a3e747ef6000c7fb1028ab09f2575f7
${ZEPHYR_USERSPACE_ELF}             ${URI}/nucleo_l552ze_q_ns--zephyr--userspace.elf-s_1653252-5e6a7c754a5a1a0d1252f09d7ae85adb757400a2
${ZEPHYR_FPU_SHARING_ELF}           ${URI}/nucleo_l552ze_q_ns--zephyr--fpu_sharing.elf-s_724424-c19b4618796e973303a436eb040cae81ccf5acc8

*** Keywords ***
Create Machine
    [Arguments]                     ${ELF}

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription "${CURDIR}${/}nucleo_l552ze_q${/}nucleo_l552ze_q_ns.repl"
    Execute Command                 sysbus LoadELF ${ELF}

    Create Terminal Tester          sysbus.lpuart1

*** Test Cases ***
Should Boot Zephyr Hello World
    Create Machine                  ${ZEPHYR_HELLO_WORLD_ELF}
    Start Emulation

    Wait For Line On Uart           Hello World! nucleo_l552ze_q

Should Pass Zephyr Protection Test
    # Test the PMSAv8 MPU
    Create Machine                  ${ZEPHYR_PROTECTION_ELF}
    Start Emulation

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr Userspace Test
    # Test the TT(T) instruction parsing
    Create Machine                  ${ZEPHYR_USERSPACE_ELF}
    Start Emulation

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr FPU Sharing Test
    # Test the EXC_RETURN value
    Create Machine                  ${ZEPHYR_FPU_SHARING_ELF}
    Start Emulation

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL  timeout=30
