*** Settings ***
Suite Setup                   Custom Suite Setup
Suite Teardown                Custom Suite Teardown
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Custom Suite Setup
    ${dirname}=               Generate Random String          10          [LETTERS]
    ${path}                   Join Path                       ${TEMPDIR}  robot-${dirname}
    Set Suite Variable        $DIRNAME                        ${path}
    Create Directory          ${DIRNAME}
    Setup

Custom Suite Teardown
    Remove Directory          ${DIRNAME}                      true
    Teardown

Create Machine
    Execute Command           using sysbus
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescriptionFromString "uart: UART.SiFive_UART @ sysbus 0x1000"

*** Test Cases ***

Should Create Uart Backend
    Create Machine

    ${base_file}=             Join Path                       ${DIRNAME}      file
    Execute Command           uart CreateFileBackend @${base_file}
    File Should Exist         ${base_file}

    Execute Command           uart CloseFileBackend @${base_file}

    ${next_file}=             Join Path                       ${DIRNAME}      file.1
    Execute Command           uart CreateFileBackend @${base_file}
    File Should Exist         ${next_file}
