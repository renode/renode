*** Settings ***
Test Setup                                         GPTP Test Setup

*** Variables ***

# The parameters are actually configurable, if the tests that
# use them fail, make sure the test is built with the default
# parameters or set the variables to the updated values
#
# NOTE: Maybe this should be somehow parametrized to take these
#       settings from the actual .config file?

${EXPECTED_PTP_PRIORITY1}                          \xf8
${EXPECTED_PTP_GM_CLOCK_CLASS}                     \xf8
${EXPECTED_PTP_GM_CLOCK_ACCURACY}                  \xfe
${EXPECTED_PTP_GM_CLOCK_VARIANCE}                  \x6a\x43
${EXPECTED_PTP_PRIORITY2}                          \xf8
${EXPECTED_PTP_TIME_SOURCE}                        \xa0

${SAM_GMAC_PTP_TIMER_SECONDS_REG}                  0x1D0

${ZEPHYR_MASTER_ELF}                               https://dl.antmicro.com/projects/renode/sam-e70_xplained--gptp-zephyr-gm.elf-s_2087900-49bb30b12c6ca60206c923771cd9cb04c09d5f35
${ZEPHYR_SLAVE_ELF}                                https://dl.antmicro.com/projects/renode/sam-e70_xplained--gptp-zephyr-nogm.elf-s_2085692-204437fef2ce19260e916a358b657d2691c9df28

*** Keywords ***

GPTP Test Setup
    Reset Emulation
    Execute Command                                emulation CreateSwitch "switch"

########################
### PACKET RECEIVERS ###
########################

Wait For Outgoing PTPv2 Packet
    # EtherType are Bytes 13-14 and should be equal to 0x88f7 for PTP packets
    # The next byte is the type of packet, and the next version (should be 0x02)

    ${pkt} =                                       Wait For Outgoing Packet With Bytes At Index  88f7__02  12  20  60
    ${bytes} =                                     Convert To Bytes  ${pkt.Bytes}

    RETURN                                         ${bytes}  ${pkt.Timestamp}

Wait For Outgoing PTPv2 Announce Packet
    # EtherType are Bytes 13-14 and should be equal to 0x88f7 for PTPv2 packets
    # Announce packet should have 0x1b at the next byte

    ${pkt} =                                       Wait For Outgoing Packet With Bytes At Index  88f71b  12  20  60
    ${bytes} =                                     Convert To Bytes  ${pkt.Bytes}

    RETURN                                         ${bytes}  ${pkt.Timestamp}

Wait For Outgoing PTPv2 Sync Packet
    # EtherType are Bytes 13-14 and should be equal to 0x88f7 for PTPv2 packets
    # Sync packet should have 0x10 at the next byte

    ${pkt} =                                       Wait For Outgoing Packet With Bytes At Index  88f710  12  20  60
    ${bytes} =                                     Convert To Bytes  ${pkt.Bytes}

    RETURN                                         ${bytes}  ${pkt.Timestamp}

Wait For Outgoing PTPv2 Sync Follow Up Packet
    # EtherType are Bytes 13-14 and should be equal to 0x88f7 for PTPv2 packets
    # Sync FUP packet should have 0x18 at the next byte

    ${pkt} =                                       Wait For Outgoing Packet With Bytes At Index  88f718  12  20  60
    ${bytes} =                                     Convert To Bytes  ${pkt.Bytes}

    RETURN                                         ${bytes}  ${pkt.Timestamp}

#######################
### GENERIC GETTERS ###
#######################

Get Timestamp From The PTP Packet
    [Arguments]   ${pktBytes}

    ${timestamp} =                                 Get Substring  ${pktBytes}  48  58

    RETURN                                         ${timestamp}

Get Clock ID From The PTP Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  34  42

    RETURN                                         ${value}

#################################
### ANNOUNCE SPECIFIC GETTERS ###
#################################

Get Priority1 From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  61  61

    RETURN                                         ${value}

Get Grand Master Clock Class From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  62  62

    RETURN                                         ${value}

Get Grand Master Clock Accuracy From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  63  63

    RETURN                                         ${value}

Get Grand Master Clock Variance From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  64  66

    RETURN                                         ${value}

Get Priority2 From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  66  66

    RETURN                                         ${value}

Get Grand Master Clock ID From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  67  75

    RETURN                                         ${value}

Get Time Source From The Announce Packet
    [Arguments]   ${pktBytes}

    ${value} =                                     Get Substring  ${pktBytes}  77  77

    RETURN                                         ${value}

#############################
### SYNC SPECIFIC GETTERS ###
#############################

Get Sync Messages Reported Period
    [Arguments]   ${pktBytes}

    ${b} =                                         Get Substring  ${pktBytes}  47  48
    ${logInterval} =                               Evaluate  ord('${b}')

    # This is a Log2 of the interval, so calculate it in milliseconds
    # (Renode uses milliseconds for timestamps)
    ${interval} =                                  Evaluate  2**(${logInterval}) * (10**3)

    RETURN                                         ${interval}

############################
### ACTUAL TEST KEYWORDS ###
############################

Should Be A PTP Packet
    [Arguments]    ${pktBytes}

    # Verify if EtherType is 0x88f7 (Bytes 12-13)

    ${etherTypePtp} =                              Convert To Bytes  \x88\xf7
    ${etherTypePkt} =                              Get Substring  ${pktBytes}  12   14

    Should Be Equal As Strings                     ${etherTypePtp}  ${etherTypePkt}

Should Be A PDelay Request Packet
    [Arguments]    ${pktBytes}

    # The byte at ofsset 14 indicates "Transport specific" and "PDelayReq" (value: 0x12)

    Should Be A PTP Packet                         ${pktBytes}

    ${ptpTypePkt} =                                Get Substring  ${pktBytes}  14   14
    ${ptpTypePDelayReqList} =                      Convert To Bytes  \x12
    ${ptpTypePDelayReq} =                          Get Substring  ${ptpTypePDelayReqList}  0    0
    Should Be Equal                                ${ptpTypePDelayReq}  ${ptpTypePkt}

PTP Clock ID Should Be Correct
    [Arguments]   ${pktBytes}

    # Correct means generated from the MAC address with 0xfffe in the middle

    # Get the Reported MAC first
    ${reportedMac} =                               Get Substring  ${pktBytes}  6    12

    # And then get the reported Clock ID and try to reconstruct the MAC
    ${reconstructedMacH0} =                        Get Substring  ${pktBytes}  34   37
    ${middleClockBytes} =                          Get Substring  ${pktBytes}  37   39
    ${reconstructedMacH1} =                        Get Substring  ${pktBytes}  39   42

    ${reconstructedMac} =                          Set Variable  ${reconstructedMacH0}${reconstructedMacH1}
    Should Be Equal As Strings                     ${reportedMac}  ${reconstructedMac}

    ${expectedMiddleClockBytes} =                  Convert To Bytes  \xff\xfe
    Should Be Equal As Strings                     ${middleClockBytes}  ${expectedMiddleClockBytes}

######################
### ANNOUNCE TESTS ###
######################

Announce Sender Should Be The Grand Master
    [Arguments]   ${pktBytes}

    # in a two-node scenario, the master node should also be the grand master node
    # verify that the node clock id and grand master id match

    ${clockId} =                                   Get Clock ID From The PTP Packet  ${pktBytes}
    ${grandMasterClockId} =                        Get Grand Master Clock ID From The Announce Packet  ${pktBytes}

    Should Be Equal As Strings                     ${clockId}  ${grandMasterClockId}

Should Announce Priority1 Equal To
    [Arguments]   ${pktBytes}  ${priority1}

    ${bytes} =                                     Convert To Bytes  ${priority1}
    ${byte} =                                      Get Substring  ${bytes}  0  0

    ${actualValue} =                               Get Priority1 From The Announce Packet  ${pktBytes}

    Should Be Equal                                ${actualValue}  ${byte}

Should Announce GM Clock Class Equal To
    [Arguments]   ${pktBytes}  ${gmClass}

    ${bytes} =                                     Convert To Bytes  ${gmClass}
    ${byte} =                                      Get Substring  ${bytes}  0  0

    ${actualValue} =                               Get Grand Master Clock Class From The Announce Packet  ${pktBytes}
    Should Be Equal                                ${actualValue}  ${byte}

Should Announce GM Clock Accuracy Equal To
    [Arguments]   ${pktBytes}  ${gmAccuracy}

    ${bytes} =                                     Convert To Bytes  ${gmAccuracy}
    ${byte} =                                      Get Substring  ${bytes}  0  0

    ${actualValue} =                               Get Grand Master Clock Accuracy From The Announce Packet  ${pktBytes}
    Should Be Equal                                ${actualValue}  ${byte}

Should Announce GM Clock Variance Equal To
    [Arguments]   ${pktBytes}  ${gmVariance}

    ${bytes} =                                     Convert To Bytes  ${gmVariance}

    ${actualValue} =                               Get Grand Master Clock Variance From The Announce Packet  ${pktBytes}
    Should Be Equal As Strings                     ${actualValue}  ${bytes}

Should Announce Priority2 Equal To
    [Arguments]   ${pktBytes}  ${priority2}

    ${bytes} =                                     Convert To Bytes  ${priority2}
    ${byte} =                                      Get Substring  ${bytes}  0  0

    ${actualValue} =                               Get Priority2 From The Announce Packet  ${pktBytes}
    Should Be Equal                                ${actualValue}  ${byte}

Should Announce Time Source Equal To
    [Arguments]   ${pktBytes}  ${timeSource}

    ${bytes} =                                     Convert To Bytes  ${timeSource}
    ${byte} =                                      Get Substring  ${bytes}  0  0

    ${actualValue} =                               Get Time Source From The Announce Packet  ${pktBytes}
    Should Be Equal                                ${actualValue}  ${byte}

Should Be Equal Within Range
    [Arguments]   ${value0}  ${value1}  ${range}

    ${diff} =                                      Evaluate  abs(${value0} - ${value1})

    Should Be True                                 ${diff} <= ${range}

Register Values Should Be Equal Within Range
    [Arguments]   ${regValue0}  ${regValue1}  ${range}

    # Renode returns it as "0xXXXX\n\n" - get the first line to trim the string
    ${regValue0} =                                 Get Line  ${regValue0}  0
    ${regValue0} =                                 Convert To Integer  ${regValue0}

    ${regValue1} =                                 Get Line  ${regValue1}  0
    ${regValue1} =                                 Convert To Integer  ${regValue1}

    Should Be Equal Within Range                   ${regValue0}  ${regValue1}  ${range}

##################
### SYNC TESTS ###
##################

Sync Packet Timestamp Should Be Empty
    [Arguments]   ${pktBytes}

    ${emptyTimestamp} =                            Convert To Bytes  \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
    ${actualTimestamp} =                           Get Timestamp From The PTP Packet  ${pktBytes}

    Should Be Equal As Strings                     ${emptyTimestamp}  ${actualTimestamp}

Sync Packet Timestamp Should Not Be Empty
    [Arguments]   ${pktBytes}

    ${emptyTimestamp} =                            Convert To Bytes  \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
    ${actualTimestamp} =                           Get Timestamp From The PTP Packet  ${pktBytes}

    Run Keyword And Expect Error                   *  Should Be Equal As Strings  ${emptyTimestamp}  ${actualTimestamp}

Should Have Synchronized Clocks
    [Arguments]   ${mach0}   ${mach1}

    Execute Command                                mach set "${mach0}"
    ${mach0Seconds} =                              Execute Command  gem ReadDoubleWord ${SAM_GMAC_PTP_TIMER_SECONDS_REG}

    Execute Command                                mach set "${mach1}"
    ${mach1Seconds} =                              Execute Command  gem ReadDoubleWord ${SAM_GMAC_PTP_TIMER_SECONDS_REG}

    # Note: this test is not really precise, because of the way we are able to send and
    #       and receive packets with Renode. Ideally we should also read the nanseconds
    #       registers, combine them with seconds to get a proper timestamp, and compare
    #       the values from both nodes with n-nanoseconds precision.

    Register Values Should Be Equal Within Range   ${mach0Seconds}  ${mach1Seconds}  1

Should Have Desynchronized Clocks
    [Arguments]   ${mach0}   ${mach1}

    Run Keyword And Expect Error                   *  Should Have Synchronized Clocks  ${mach0}  ${mach1}

#####################
### SETUP HELPERS ###
#####################

Setup Slave Node
    [Arguments]   ${name}

    Execute Command                                set bin @${ZEPHYR_SLAVE_ELF}
    Execute Command                                set name "${name}"
    Execute Command                                i @scripts/single-node/sam_e70.resc
    Execute Command                                connector Connect gem switch
    Execute Command                                mach clear

Setup Master Node
    [Arguments]   ${name}

    Execute Command                                set bin @${ZEPHYR_MASTER_ELF}
    Execute Command                                set name "${name}"
    Execute Command                                i @scripts/single-node/sam_e70.resc
    Execute Command                                connector Connect gem switch
    Execute Command                                mach clear

Setup Single Node Scenario
    Setup Master Node                              master

Setup Multi Node Scenario
    Setup Master Node                              master
    Setup Slave Node                               slave

    Execute Command                                emulation SetGlobalSerialExecution True

*** Test Cases ***

Single Node Should Send A PDelay Request Packet
    Setup Single Node Scenario
    Create Network Interface Tester                sysbus.gem
    Start Emulation

    ${pkt}  ${ts} =                                Wait For Outgoing PTPv2 Packet

    Should Be A PDelay Request Packet              ${pkt}

Slave Should Call The Phase Dis Callback
    Setup Multi Node Scenario
    Create Terminal Tester                         sysbus.usart1  machine=slave
    Start Emulation

    Wait For Line On Uart                          net_gptp_sample.gptp_phase_dis_cb

Master Should Send Announce Packets With The Expected Parameters
    Setup Multi Node Scenario
    Create Network Interface Tester                sysbus.gem  master
    Start Emulation

    ${pkt}  ${ts} =                                Wait For Outgoing PTPv2 Announce Packet

    PTP Clock ID Should Be Correct                 ${pkt}
    Announce Sender Should Be The Grand Master     ${pkt}

    Should Announce Priority1 Equal To             ${pkt}  ${EXPECTED_PTP_PRIORITY1}
    Should Announce GM Clock Class Equal To        ${pkt}  ${EXPECTED_PTP_GM_CLOCK_CLASS}
    Should Announce GM Clock Accuracy Equal To     ${pkt}  ${EXPECTED_PTP_GM_CLOCK_ACCURACY}
    Should Announce GM Clock Variance Equal To     ${pkt}  ${EXPECTED_PTP_GM_CLOCK_VARIANCE}
    Should Announce Priority2 Equal To             ${pkt}  ${EXPECTED_PTP_PRIORITY2}
    Should Announce Time Source Equal To           ${pkt}  ${EXPECTED_PTP_TIME_SOURCE}

Master Should Send Sync And Fup Packets With The Expected Parameters
    Setup Multi Node Scenario
    Create Network Interface Tester                sysbus.gem  master
    Start Emulation

    ${pkt}  ${ts} =                                Wait For Outgoing PTPv2 Sync Packet
    Sync Packet Timestamp Should Be Empty          ${pkt}

    ${pkt}  ${ts} =                                Wait For Outgoing PTPv2 Sync Follow Up Packet
    Sync Packet Timestamp Should Not Be Empty      ${pkt}

Master Should Send Syncs In Valid Intervals
    Setup Multi Node Scenario
    Create Network Interface Tester                sysbus.gem  master

    Start Emulation

    ${pkt}  ${ts} =                                Wait For Outgoing PTPv2 Sync Packet

    ${range} =                                     Get Sync Messages Reported Period  ${pkt}

    ${pkt}  ${ts0} =                               Wait For Outgoing PTPv2 Sync Packet
    ${pkt}  ${ts1} =                               Wait For Outgoing PTPv2 Sync Packet

    # Assume 100% interval error is alright for renode ;)
    ${rangeErr} =                                  Evaluate  ${range}*1.0

    Should Be Equal Within Range                   ${ts1} - ${ts0} - ${range}  0  ${rangeErr}

Slave Should Sync Its Clock To Master
    Setup Multi Node Scenario
    Execute Command                                mach set "slave"
    Execute Command                                cpu IsHalted true
    Execute Command                                emulation RunFor "5"
    Execute Command                                gem Reset

    Should Have Desynchronized Clocks              slave  master

    Execute Command                                mach set "slave"
    Execute Command                                cpu IsHalted false
    Execute Command                                emulation RunFor "5"

    Should Have Synchronized Clocks                slave  master
