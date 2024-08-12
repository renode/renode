*** Settings ***
Library                             telnet_library.py

*** Variables ***
${READ_END_MARKER}                  TEST

*** Test Cases ***
Should Attach To Server Socket Terminal
    Execute Command                 mach create

    ${RENODE_LOG_PORT}=             Find Free Port
    Execute Command                 logNetwork ${RENODE_LOG_PORT}
    Telnet Connect                  ${RENODE_LOG_PORT}

    Execute Command                 log "${READ_END_MARKER}"

    ${log_data}=                    Telnet Read Until  ${READ_END_MARKER}
    Should Contain                  ${log_data}  ${READ_END_MARKER}
