*** Settings ***
Resource                      ${RENODEKEYWORDS}
Resource                      common_keywords.robot

*** Comments ***
Over-the-air receive coverage for the xG22, xG24 and xG301 LPW models. A pair (or triple) of machines is connected
through an IEEE 802.15.4 medium and driven by RAC FORCESTATE, so the tests exercise the radio
model rather than firmware.

The suite covers the happy path and the main drop reasons: wrong channel, receiver idle,
incompatible PHY, sync mismatch, joining after the packet is gone, and co-channel collisions.

*** Variables ***
@{LPW_MODELS}                  xG22  xG24  xG301
${PLATFORM_FILE}               platforms/boards/silabs/brd1019a.repl
${FRC_BLOCK_ADDRESS}           0xA0204000
${RAC_BLOCK_ADDRESS}           0xA0220000
${BUFC_BLOCK_ADDRESS}          0xA0300000
${TX_MODEM_BLOCK_ADDRESS}      0xA0214000
${RX_MODEM_BLOCK_ADDRESS}      0xA0214000
${SYNTH_BLOCK_ADDRESS}         0xA0218000
${BUFC_RAM_ADDRESS}            0x20000000
${FRC_DFLCTRL_REG}             0x000C
${FRC_WCNTCMP0_REG}            0x0020
${FRC_FCD0_REG}                0x0110
${RAC_FORCESTATE_REG}          0x0018
${RAC_FORCESTATE_RXSEARCH}     0x2
${RAC_FORCESTATE_TX}           0x6
${MODULATOR_TXBR_REG}          0x0078
${MODULATOR_TXBR_VALUE}        0xD20D
# Roughly half of the default baud, well outside the 5% decode-compatibility tolerance.
${MODULATOR_TXBR_HALF}         0x6906
${MODEM_CTRL0_REG}             0x005C
${MODEM_CTRL1_REG}             0x0060
${MODEM_CTRL0_CODING_SHIFT}    4
${MODEM_CODING_LINECODE}       3
# SYNCBITS=7 => 8-bit sync word (one byte).
${MODEM_SYNCBITS_8}            7
${MODEM_PREAMBLE_REG}          0x0084
# TXBASES=8000, BASEBITS=0 => 8000 preamble bits, about 8ms at ~1Mbps (exact airtime
# varies a bit by model HFXO / TXBR programming).
${MODEM_PREAMBLE_VALUE}        0x1F400000
${MODEM_SYNC0_REG}             0x0480
${MODEM_SYNC_CUSTOM}           0xAA
${SYNTH_FREQ_REG}              0x0030
${SYNTH_FREQ_CHANNEL_A}        0x01000000
${SYNTH_FREQ_CHANNEL_B}        0x01080000
${BUFC_BUF0_ADDR_REG}          0x0010
${BUFC_BUF0_WRITEOFFSET_REG}   0x0014
${BUFC_BUF0_READOFFSET_REG}    0x0018
${BUFC_BUFFER_STRIDE}          0x40
${FCD_BUFFER_SHIFT}            8
${SYNC_PREFIX}                 00
${SYNC_PREFIX_CUSTOM}          AA
# Well before half of the ~8ms preamble, so a second transmitter starts while the first is still on air.
${JOIN_DURING_PREAMBLE}        0.001
${RX_SETTLE}                   0.030

*** Keywords ***
Select LPW Model
    [Arguments]  ${model}
    IF  '${model}' == 'xG22'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd4182a.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA8004000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA8020000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x9
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xAA000000
        Set Suite Variable      ${BUFC_BUF0_ADDR_REG}         0x0010
        Set Suite Variable      ${BUFC_BUF0_WRITEOFFSET_REG}  0x0014
        Set Suite Variable      ${BUFC_BUF0_READOFFSET_REG}   0x0018
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA8018000
        Set Suite Variable      ${FRC_DFLCTRL_REG}            0x000C
        Set Suite Variable      ${FRC_WCNTCMP0_REG}           0x0020
        Set Suite Variable      ${FRC_FCD0_REG}               0x0104
        Set Suite Variable      ${MODULATOR_TXBR_REG}         0x0058
        Set Suite Variable      ${MODULATOR_TXBR_VALUE}       0x00080027
        Set Suite Variable      ${MODULATOR_TXBR_HALF}        0x0008004E
        Set Suite Variable      ${MODEM_CTRL0_REG}            0x0020
        Set Suite Variable      ${MODEM_CTRL1_REG}            0x0024
        Set Suite Variable      ${MODEM_PREAMBLE_REG}         0x0064
        Set Suite Variable      ${MODEM_SYNC0_REG}            0x0068
        Set Suite Variable      ${SYNTH_FREQ_REG}             0x0034
    ELSE IF  '${model}' == 'xG24'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd4186c.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA8004000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA8020000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x9
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xAA000000
        Set Suite Variable      ${BUFC_BUF0_ADDR_REG}         0x0010
        Set Suite Variable      ${BUFC_BUF0_WRITEOFFSET_REG}  0x0014
        Set Suite Variable      ${BUFC_BUF0_READOFFSET_REG}   0x0018
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA8018000
        Set Suite Variable      ${FRC_DFLCTRL_REG}            0x000C
        Set Suite Variable      ${FRC_WCNTCMP0_REG}           0x0020
        Set Suite Variable      ${FRC_FCD0_REG}               0x0108
        Set Suite Variable      ${MODULATOR_TXBR_REG}         0x0068
        Set Suite Variable      ${MODULATOR_TXBR_VALUE}       0x00080027
        Set Suite Variable      ${MODULATOR_TXBR_HALF}        0x0008004E
        Set Suite Variable      ${MODEM_CTRL0_REG}            0x004C
        Set Suite Variable      ${MODEM_CTRL1_REG}            0x0050
        Set Suite Variable      ${MODEM_PREAMBLE_REG}         0x0074
        Set Suite Variable      ${MODEM_SYNC0_REG}            0x0078
        Set Suite Variable      ${SYNTH_FREQ_REG}             0x0034
    ELSE IF  '${model}' == 'xG301'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd1019a.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA0204000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA0220000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x6
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xA0300000
        Set Suite Variable      ${BUFC_BUF0_ADDR_REG}         0x0010
        Set Suite Variable      ${BUFC_BUF0_WRITEOFFSET_REG}  0x0014
        Set Suite Variable      ${BUFC_BUF0_READOFFSET_REG}   0x0018
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA0214000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA0214000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA0218000
        Set Suite Variable      ${FRC_DFLCTRL_REG}            0x000C
        Set Suite Variable      ${FRC_WCNTCMP0_REG}           0x0020
        Set Suite Variable      ${FRC_FCD0_REG}               0x0110
        Set Suite Variable      ${MODULATOR_TXBR_REG}         0x0078
        Set Suite Variable      ${MODULATOR_TXBR_VALUE}       0xD20D
        Set Suite Variable      ${MODULATOR_TXBR_HALF}        0x6906
        Set Suite Variable      ${MODEM_CTRL0_REG}            0x005C
        Set Suite Variable      ${MODEM_CTRL1_REG}            0x0060
        Set Suite Variable      ${MODEM_PREAMBLE_REG}         0x0084
        Set Suite Variable      ${MODEM_SYNC0_REG}            0x0480
        Set Suite Variable      ${SYNTH_FREQ_REG}             0x0030
    ELSE
        Fail                    Unknown LPW model: ${model}
    END

Create Wireless Pair
    Reset Emulation
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             emulation SetQuantum "0.000050"
    Execute Command             emulation CreateIEEE802_15_4Medium "wireless"
    Create Log Tester           1
    Execute Command             logLevel 1
    Create Radio Node           tx
    Create Radio Node           rx
    Execute Command             connector Connect sysbus.radio wireless  machine=tx
    Execute Command             connector Connect sysbus.radio wireless  machine=rx

Create Wireless Triple
    Create Wireless Pair
    Create Radio Node           tx2
    Execute Command             connector Connect sysbus.radio wireless  machine=tx2

Create Radio Node
    [Arguments]  ${name}
    Execute Command             mach create "${name}"
    Execute Command             machine LoadPlatformDescription @${PLATFORM_FILE}  machine=${name}
    Execute Command             cpu IsHalted true  machine=${name}
    Configure Phy               ${name}
    Configure Long Preamble     ${name}

Configure Phy
    [Arguments]  ${name}  ${txbr}=${MODULATOR_TXBR_VALUE}
    ${addr}=                    Evaluate  ${TX_MODEM_BLOCK_ADDRESS} + ${MODULATOR_TXBR_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} ${txbr}  machine=${name}

Configure Long Preamble
    [Arguments]  ${name}
    ${addr}=                    Evaluate  ${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_PREAMBLE_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} ${MODEM_PREAMBLE_VALUE}  machine=${name}

Configure Sync Word
    [Arguments]  ${name}  ${sync}
    ${tx_ctrl1}=                Evaluate  ${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL1_REG}
    ${rx_ctrl1}=                Evaluate  ${RX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL1_REG}
    Execute Command             sysbus WriteDoubleWord ${tx_ctrl1} ${MODEM_SYNCBITS_8}  machine=${name}
    Execute Command             sysbus WriteDoubleWord ${rx_ctrl1} ${MODEM_SYNCBITS_8}  machine=${name}
    ${tx_sync0}=                Evaluate  ${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_SYNC0_REG}
    ${rx_sync0}=                Evaluate  ${RX_MODEM_BLOCK_ADDRESS} + ${MODEM_SYNC0_REG}
    Execute Command             sysbus WriteDoubleWord ${tx_sync0} ${sync}  machine=${name}
    Execute Command             sysbus WriteDoubleWord ${rx_sync0} ${sync}  machine=${name}

Select Linecode Phy
    [Arguments]  ${name}
    ${addr}=                    Evaluate  ${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL0_REG}
    ${current}=                 Execute Command  sysbus ReadDoubleWord ${addr}  machine=${name}
    ${value}=                   Evaluate  (int(${current}) & ~(0x3 << ${MODEM_CTRL0_CODING_SHIFT})) | (${MODEM_CODING_LINECODE} << ${MODEM_CTRL0_CODING_SHIFT})
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}  machine=${name}

Tune Channel
    [Arguments]  ${name}  ${freq}
    ${addr}=                    Evaluate  ${SYNTH_BLOCK_ADDRESS} + ${SYNTH_FREQ_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} ${freq}  machine=${name}

Force State
    [Arguments]  ${name}  ${state}
    ${addr}=                    Evaluate  ${RAC_BLOCK_ADDRESS} + ${RAC_FORCESTATE_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} ${state}  machine=${name}

Prepare Tx Frame
    [Arguments]  ${name}
    Configure Fixed Frame Length  ${name}  4
    Write Frame Descriptor      ${name}  0  4  0
    Load Bufc Buffer            ${name}  0  0x11  0x22  0x33  0x44

Configure Fixed Frame Length
    [Arguments]  ${name}  ${bytes}
    ${addr}=                    Evaluate  ${FRC_BLOCK_ADDRESS} + ${FRC_DFLCTRL_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} 0  machine=${name}
    ${framelength}=             Evaluate  ${bytes} - 1
    ${addr}=                    Evaluate  ${FRC_BLOCK_ADDRESS} + ${FRC_WCNTCMP0_REG}
    Execute Command             sysbus WriteDoubleWord ${addr} ${framelength}  machine=${name}

Write Frame Descriptor
    [Arguments]  ${name}  ${index}  ${words}  ${buffer}
    ${value}=                   Evaluate  (${words} - 1) | (${buffer} << ${FCD_BUFFER_SHIFT})
    ${offset}=                  Evaluate  ${FRC_FCD0_REG} + 4 * ${index}
    ${addr}=                    Evaluate  ${FRC_BLOCK_ADDRESS} + ${offset}
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}  machine=${name}

Load Bufc Buffer
    [Arguments]  ${name}  ${buffer}  @{bytes}
    ${ram_address}=             Evaluate  ${BUFC_RAM_ADDRESS} + ${buffer} * 0x100
    ${nbytes}=                  Get Length  ${bytes}
    FOR  ${i}  IN RANGE  ${nbytes}
        ${byte}=                Evaluate  ${bytes}[${i}]
        ${addr}=                Evaluate  ${ram_address} + ${i}
        Execute Command         sysbus WriteByte ${addr} ${byte}  machine=${name}
    END
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_ADDR_REG}  ${ram_address}
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_READOFFSET_REG}  0
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  ${nbytes}

Write Bufc Register
    [Arguments]  ${name}  ${buffer}  ${offset}  ${value}
    ${addr}=                    Evaluate  ${BUFC_BLOCK_ADDRESS} + ${offset} + ${buffer} * ${BUFC_BUFFER_STRIDE}
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}  machine=${name}

Start Tx
    [Arguments]  ${name}
    Prepare Tx Frame            ${name}
    Execute Command             emulation RunFor "0.0001"
    Force State                 ${name}  ${RAC_FORCESTATE_TX}

Frame Should Be Received
    [Arguments]  ${prefix}=${SYNC_PREFIX}
    Wait For Log Entry          Received at .*: ${prefix}-11-22-33-44  treatAsRegex=true

Frame Should Not Be Received
    Should Not Be In Log        Received at

*** Test Cases ***
On Channel Rx From Tx Start Succeeds Without Collision
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Frame Should Be Received
        Should Not Be In Log        RX already ongoing - collision
    END

Matching Custom Sync Word Succeeds
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Configure Sync Word         tx  ${MODEM_SYNC_CUSTOM}
        Configure Sync Word         rx  ${MODEM_SYNC_CUSTOM}
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Frame Should Be Received    ${SYNC_PREFIX_CUSTOM}
    END

Off Channel Receiver Does Not Receive
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_B}
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Frame Should Not Be Received
    END

Receiver Idle During Transmission Does Not Receive
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Frame Should Not Be Received
    END

Incompatible Coding Drops
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Select Linecode Phy         rx
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Wait For Log Entry          Dropping: (incompatible PHY  timeout=1
        Frame Should Not Be Received
    END

Incompatible Data Rate Drops
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Configure Phy               rx  ${MODULATOR_TXBR_HALF}
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Wait For Log Entry          Dropping: (incompatible PHY  timeout=1
        Frame Should Not Be Received
    END

Sync Word Mismatch Drops
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Configure Sync Word         tx  ${MODEM_SYNC_CUSTOM}
        Configure Sync Word         rx  0x00
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Wait For Log Entry          Dropping (SYNC MISMATCH)  timeout=1
        Frame Should Not Be Received
    END

Enter RxSearch After Transmission Completes Does Not Receive
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Pair
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Start Tx                    tx
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Execute Command             emulation RunFor "0.001"
        Frame Should Not Be Received
    END

Second Transmitter Collides With Ongoing Rx
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Triple
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                tx2  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Start Tx                    tx
        Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
        Start Tx                    tx2
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Wait For Log Entry          RX already ongoing - collision  timeout=1
        Wait For Log Entry          Dropping (PRE/SYNC COLLISION)  timeout=1
        Frame Should Not Be Received
    END

Join While Two Packets Are On Air Drops
    FOR  ${model}  IN  @{LPW_MODELS}
        Select LPW Model            ${model}
        Create Wireless Triple
        Tune Channel                tx  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                tx2  ${SYNTH_FREQ_CHANNEL_A}
        Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
        Start Tx                    tx
        Start Tx                    tx2
        Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
        Execute Command             emulation RunFor "${RX_SETTLE}"
        Wait For Log Entry          RX starting with co-channel interference already on air  timeout=1
        Wait For Log Entry          Dropping (PRE/SYNC COLLISION)  timeout=1
        Frame Should Not Be Received
    END
