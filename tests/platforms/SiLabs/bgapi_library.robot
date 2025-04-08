*** Settings ***
Library                         ${CURDIR}/bgapi_library.py

*** Variables ***
${XAPI}                         ${CURDIR}/sl_bt.xapi
${DEFAULT_TIMEOUT}              2
${DEFAULT_INTERVAL}             0.1

*** Keywords ***
###############################################################################################
# Host to NCP connection keywords
###############################################################################################

Ble Open Host Connection
    [Arguments]  ${descriptor}
    ${ret}=                        Bgapi Open Host Connection  ${descriptor}  ${XAPI}
    RETURN  ${ret}

Ble Close All Host Connections
    Bgapi Close All Host Connections

###############################################################################################
# BGAPI commands keywords
###############################################################################################

Ble Hello
    [Arguments]  ${tester_id}
    Execute Command                start
    ${response}=                   Bgapi Hello  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}

Ble Get Address
    [Arguments]  ${tester_id}
    Execute Command                start
    ${response}=                   Bgapi Get Identity Address  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}
    RETURN  ${response.address}

Ble Legacy Advertiser Create Set
    [Arguments]  ${tester_id}
    Execute Command                start
    ${response}=                   Bgapi Legacy Advertiser Create Set  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}
    RETURN  ${response.handle}

Ble Legacy Advertiser Generate Data
    [Arguments]  ${handle}  ${mode}  ${tester_id}  
    Execute Command                start
    ${response}=                   Bgapi Legacy Advertiser Generate Data  ${handle}  ${mode}  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}

Ble Legacy Advertiser Start
    [Arguments]  ${handle}  ${mode}  ${tester_id}  
    Execute Command                start
    ${response}=                   Bgapi Legacy Advertiser Start  ${handle}  ${mode}  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}

Ble Connection Open
    [Arguments]  ${address}  ${address_type}  ${tester_id}  
    Execute Command                start
    ${response}=                   Bgapi Connection Open  ${address}  ${address_type}  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}
    RETURN   ${response.connection}

Ble Write Characteristic Value
    [Arguments]  ${connection}  ${characteristic}  ${value}  ${tester_id}
    Execute Command                start
    ${response}=                   Bgapi Gatt Write Characteristic Value  ${connection}  ${characteristic}  ${value}  ${tester_id}
    Execute Command                pause
    Check Response Status          ${response}


###############################################################################################
# Event keywords
###############################################################################################

Ble Wait For Boot Event
    [Arguments]  ${tester_id}
    Wait For Event                 bt_evt_system_boot  ${tester_id}

Ble Wait For Connection Opened Event
    [Arguments]  ${tester_id}
    ${evt}=                        Wait For Event  bt_evt_connection_opened  ${tester_id}
    RETURN  ${evt.connection}

Ble Assert No Connection Closed Event
    [Arguments]  ${tester_id}
    Assert Event Not In Queue      bt_evt_connection_closed  ${tester_id}

Ble Assert Event Queue Is Empty
    [Arguments]  ${tester_id}
    ${evt}=                    Bgapi Get Pending Event  ${tester_id}
    ${evt}=                    Convert To String  ${evt}
    Should Be Equal            ${evt}  None  msg="Event queue not empty"

###############################################################################################
# Internal utility keywords
###############################################################################################

Check Response Status
    [Arguments]  ${response}
    IF  ${response.result} != 0
        Fail                       Response Status unsuccessful: ${response.result}
    END

Wait For Event
    [Arguments]  ${event}  ${tester_id}
    ${max_attempts}=               Evaluate  ${DEFAULT_TIMEOUT} / ${DEFAULT_INTERVAL}
    ${attempts}=                   Set Variable  0
    WHILE  ${attempts} < ${max_attempts}
        ${evt}=                    Bgapi Get Pending Event  ${tester_id}
        IF  "None" == "${evt}"
            Execute Command        emulation RunFor "${DEFAULT_INTERVAL}"
            ${attempts}=           Evaluate  ${attempts} + 1
        ELSE
            ${evt_str}             Convert To String  ${evt}
            ${event_str}           Convert To String  ${event}
            Should Contain         ${evt_str}  ${event_str}  msg="Event not in queue: "${event}
            RETURN  ${evt}
        END
    END
    IF  ${attempts} == ${max_attempts}
        Fail                      Did not get event ${event}
    END

Flush Events
    [Arguments]  ${tester_id}
    ${empty}=                     Set Variable  False
    WHILE  ${empty} == False
        ${evt}=                       Bgapi Get Pending Event  ${tester_id}
        IF  "None" == "${evt}"
            ${empty}=                 Set Variable  True
        END
    END

Assert Event Not In Queue
    [Arguments]  ${event}  ${tester_id}
    ${empty}=                     Set Variable  False
    WHILE  ${empty} == False
        ${evt}=                       Bgapi Get Pending Event  ${tester_id}
        IF  "None" == "${evt}"
            ${empty}=                 Set Variable  True
        ELSE
            ${evt_str}             Convert To String  ${evt}
            ${event_str}           Convert To String  ${event}
            Should Not Contain     ${evt_str}  ${event_str}  msg="Unexpected event in queue: "${event}
        END
    END
