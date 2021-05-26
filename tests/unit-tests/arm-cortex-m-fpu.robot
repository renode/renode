*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${ZEPHYR_GENERIC_BIN}           @https://dl.antmicro.com/projects/renode/frdm_k64f--zephyr-fpu_sharing_generic.elf-s_861928-bef2795db6dd11f8106387ff6c6afd35686c48de

*** Test Cases ***
Should Pass Zephyr FPU Sharing Generic Tests
    [Tags]                      non_critical
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @platforms/cpus/nxp-k6xf.repl
    Create Terminal Tester      sysbus.uart0
    Execute Command             sysbus LoadELF ${ZEPHYR_GENERIC_BIN}

    Start Emulation
    ${result}=                  Wait For Prompt On Uart  PROJECT EXECUTION  timeout=32
    Should Contain              ${result.line}  SUCCESSFUL
