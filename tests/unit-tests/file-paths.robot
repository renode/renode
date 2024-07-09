*** Settings ***
Suite Setup                         Custom Suite Setup
Suite Teardown                      Custom Suite Teardown

*** Variables ***
${EXISTING_PLATFORM}                platforms/cpus/miv.repl

*** Keywords ***
Custom Suite Setup
    ${dirname}=                     Generate Random String  10  [LETTERS]
    ${path}=                        Join Path  ${TEMPDIR}  robot-${dirname}
    Set Suite Variable              ${SUITE_TEMPDIR}  ${path}
    Create Directory                ${SUITE_TEMPDIR}
    Setup

Custom Suite Teardown
    # It seems that on Windows, locks to "logFile"s are still being held after "Clear"
    # preventing Teardown, so some tests are temporarily marked as "skip_windows" until this issue is resolved
    Execute Command                 Clear
    Remove Directory                ${SUITE_TEMPDIR}  true
    Teardown

Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "uart: UART.SiFive_UART @ sysbus 0x1000"

Create Temporary REPL File
    [Arguments]                     ${repl_filename}
    ${file_path}=                   Join Path  ${SUITE_TEMPDIR}  ${repl_filename}
    Create File                     ${file_path}
    RETURN                          ${file_path}

Should Have Loaded REPL
    ${peripherals}=                 Execute Command  peripherals
    Should Contain                  ${peripherals}  sysbus

*** Test Cases ***
Should Create Uart Backend
    Create Machine

    ${base_file}=                   Join Path  ${SUITE_TEMPDIR}  file
    Execute Command                 uart CreateFileBackend @${base_file}
    File Should Exist               ${base_file}

    Execute Command                 uart CloseFileBackend @${base_file}

    ${next_file}=                   Join Path  ${SUITE_TEMPDIR}  file.1
    Execute Command                 uart CreateFileBackend @${base_file}
    File Should Exist               ${next_file}

Should Create Subsequent Log Files
    [Tags]                          skip_windows
    ${base_file}=                   Join Path  ${SUITE_TEMPDIR}  logfile
    Execute Command                 logFile @${base_file}
    File Should Exist               ${base_file}

    ${next_file}=                   Join Path  ${SUITE_TEMPDIR}  logfile.1
    Execute Command                 logFile @${base_file}
    File Should Exist               ${next_file}

Should Create Platform Using Command
    Execute Command                 include @${EXISTING_PLATFORM}
    Should Have Loaded REPL

Should Create Platform Using Method
    Execute Command                 mach create

    Execute Command                 machine LoadPlatformDescription @${EXISTING_PLATFORM}
    Should Have Loaded REPL

Should Create Platform Using Command With String Argument
    # Using a string argument allows spaces in the file path.
    Execute Command                 include "${EXISTING_PLATFORM}"
    ${repl}=                        Create Temporary REPL File  Platform With Spaces.repl
    Execute Command                 include "${repl}"
    Should Have Loaded REPL

Should Create Platform Using Method With String Argument
    Execute Command                 mach create

    Execute Command                 machine LoadPlatformDescription "${EXISTING_PLATFORM}"
    ${repl}=                        Create Temporary REPL File  Platform With Spaces.repl
    Execute Command                 machine LoadPlatformDescription "${repl}"
    Should Have Loaded REPL
