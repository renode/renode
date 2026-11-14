*** Comments ***
Over-the-air receive coverage for the xG22, xG24 and xG301 SiLabs LPW models. A pair (or triple)
of machines is connected through an IEEE 802.15.4 medium and driven by RAC FORCESTATE, so the
tests exercise the radio model rather than firmware.

The suite covers the happy path, late-preamble join, and the main drop reasons: wrong channel,
receiver idle, incompatible PHY, sync mismatch, TX abort, retune-away, joining after the
packet is gone, and co-channel collisions.

*** Variables ***
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
${RAC_FORCESTATE_OFF}          0x0
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
${BUFC_BUF0_CTRL_REG}          0x000C
# SIZE field: 64 << SIZE bytes. The reset value gives 64 bytes, too small for a long frame.
${BUFC_SIZE_256}               0x2
${BUFC_BUF0_ADDR_REG}          0x0010
${BUFC_BUF0_WRITEOFFSET_REG}   0x0014
${BUFC_BUF0_READOFFSET_REG}    0x0018
${BUFC_BUFFER_STRIDE}          0x40
${FCD_BUFFER_SHIFT}            8
${SYNC_PREFIX}                 00
${SYNC_PREFIX_CUSTOM}          AA
# Well before half of the ~8ms preamble, so enough of it is still ahead to lock onto.
${JOIN_DURING_PREAMBLE}        0.001
# Past half of the preamble on every model, so too little of it is left to lock onto.
${JOIN_LATE_IN_PREAMBLE}       0.006
# After the whole preamble on every model: the sync word is already on air.
${JOIN_AFTER_SYNC}             0.0084
# Long enough that aborting after JOIN_AFTER_SYNC still lands in the payload, not after TX done.
${LONG_FRAME_BYTES}            200
${RX_SETTLE}                   0.030

*** Keywords ***
Select LPW Model
    [Arguments]  ${model}
    IF  '${model}' == 'xg22'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd4182a.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA8004000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA8020000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x9
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xAA000000
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA8018000
        Set Suite Variable      ${FRC_FCD0_REG}               0x0104
        Set Suite Variable      ${MODULATOR_TXBR_REG}         0x0058
        Set Suite Variable      ${MODULATOR_TXBR_VALUE}       0x00080027
        Set Suite Variable      ${MODULATOR_TXBR_HALF}        0x0008004E
        Set Suite Variable      ${MODEM_CTRL0_REG}            0x0020
        Set Suite Variable      ${MODEM_CTRL1_REG}            0x0024
        Set Suite Variable      ${MODEM_PREAMBLE_REG}         0x0064
        Set Suite Variable      ${MODEM_SYNC0_REG}            0x0068
        Set Suite Variable      ${SYNTH_FREQ_REG}             0x0034
    ELSE IF  '${model}' == 'xg24'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd4186c.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA8004000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA8020000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x9
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xAA000000
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA8014000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA8018000
        Set Suite Variable      ${FRC_FCD0_REG}               0x0108
        Set Suite Variable      ${MODULATOR_TXBR_REG}         0x0068
        Set Suite Variable      ${MODULATOR_TXBR_VALUE}       0x00080027
        Set Suite Variable      ${MODULATOR_TXBR_HALF}        0x0008004E
        Set Suite Variable      ${MODEM_CTRL0_REG}            0x004C
        Set Suite Variable      ${MODEM_CTRL1_REG}            0x0050
        Set Suite Variable      ${MODEM_PREAMBLE_REG}         0x0074
        Set Suite Variable      ${MODEM_SYNC0_REG}            0x0078
        Set Suite Variable      ${SYNTH_FREQ_REG}             0x0034
    ELSE IF  '${model}' == 'xg301'
        Set Suite Variable      ${PLATFORM_FILE}              platforms/boards/silabs/brd1019a.repl
        Set Suite Variable      ${FRC_BLOCK_ADDRESS}          0xA0204000
        Set Suite Variable      ${RAC_BLOCK_ADDRESS}          0xA0220000
        Set Suite Variable      ${RAC_FORCESTATE_TX}          0x6
        Set Suite Variable      ${BUFC_BLOCK_ADDRESS}         0xA0300000
        Set Suite Variable      ${TX_MODEM_BLOCK_ADDRESS}     0xA0214000
        Set Suite Variable      ${RX_MODEM_BLOCK_ADDRESS}     0xA0214000
        Set Suite Variable      ${SYNTH_BLOCK_ADDRESS}        0xA0218000
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
        Fail                    Unsupported LPW model: ${model}
    END

Create Wireless Pair
    [Arguments]  ${model}  ${rx_channel}=${SYNTH_FREQ_CHANNEL_A}
    Select LPW Model            ${model}
    Reset Emulation
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             emulation SetQuantum "0.000050"
    Execute Command             emulation CreateIEEE802_15_4Medium "wireless"
    Create Log Tester           1
    Execute Command             logLevel 1
    Create Radio Node           tx  ${SYNTH_FREQ_CHANNEL_A}
    Create Radio Node           rx  ${rx_channel}

Create Wireless Triple
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Create Radio Node           tx2  ${SYNTH_FREQ_CHANNEL_A}

Create Radio Node
    [Arguments]  ${name}  ${channel}
    Execute Command             mach create "${name}"
    Execute Command             machine LoadPlatformDescription @${PLATFORM_FILE}  machine=${name}
    Execute Command             cpu IsHalted true  machine=${name}
    Configure Phy               ${name}
    Execute Command             sysbus WriteDoubleWord ${{${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_PREAMBLE_REG}}} ${MODEM_PREAMBLE_VALUE}
    ...                         machine=${name}
    Execute Command             connector Connect sysbus.radio wireless  machine=${name}
    Tune Channel                ${name}  ${channel}

Configure Phy
    [Arguments]  ${name}  ${txbr}=${MODULATOR_TXBR_VALUE}
    Execute Command             sysbus WriteDoubleWord ${{${TX_MODEM_BLOCK_ADDRESS} + ${MODULATOR_TXBR_REG}}} ${txbr}  machine=${name}

Configure Sync Word
    [Arguments]  ${name}  ${sync}
    Execute Command             sysbus WriteDoubleWord ${{${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL1_REG}}} ${MODEM_SYNCBITS_8}
    ...                         machine=${name}
    Execute Command             sysbus WriteDoubleWord ${{${RX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL1_REG}}} ${MODEM_SYNCBITS_8}
    ...                         machine=${name}
    Execute Command             sysbus WriteDoubleWord ${{${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_SYNC0_REG}}} ${sync}  machine=${name}
    Execute Command             sysbus WriteDoubleWord ${{${RX_MODEM_BLOCK_ADDRESS} + ${MODEM_SYNC0_REG}}} ${sync}  machine=${name}

Select Linecode Phy
    [Arguments]  ${name}
    ${addr}=                    Set Variable  ${{${TX_MODEM_BLOCK_ADDRESS} + ${MODEM_CTRL0_REG}}}
    ${current}=                 Execute Command  sysbus ReadDoubleWord ${addr}  machine=${name}
    ${cleared}=                 Set Variable  ${{int($current.strip(), 16) & ~(0x3 << ${MODEM_CTRL0_CODING_SHIFT})}}
    Execute Command             sysbus WriteDoubleWord ${addr} ${{${cleared} | (${MODEM_CODING_LINECODE} << ${MODEM_CTRL0_CODING_SHIFT})}}
    ...                         machine=${name}

Tune Channel
    [Arguments]  ${name}  ${freq}
    Execute Command             sysbus WriteDoubleWord ${{${SYNTH_BLOCK_ADDRESS} + ${SYNTH_FREQ_REG}}} ${freq}  machine=${name}

Force State
    [Arguments]  ${name}  ${state}
    Execute Command             sysbus WriteDoubleWord ${{${RAC_BLOCK_ADDRESS} + ${RAC_FORCESTATE_REG}}} ${state}  machine=${name}

Load Bufc Buffer
    [Arguments]  ${name}  ${buffer}  @{bytes}
    ${ram_address}=             Set Variable  ${{${BUFC_RAM_ADDRESS} + ${buffer} * 0x100}}
    FOR  ${i}  ${byte}  IN ENUMERATE  @{bytes}
        Execute Command         sysbus WriteByte ${{${ram_address} + ${i}}} ${byte}  machine=${name}
    END
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_ADDR_REG}  ${ram_address}
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_READOFFSET_REG}  0
    Write Bufc Register         ${name}  ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  ${{len($bytes)}}

Write Bufc Register
    [Arguments]  ${name}  ${buffer}  ${offset}  ${value}
    Execute Command             sysbus WriteDoubleWord ${{${BUFC_BLOCK_ADDRESS} + ${offset} + ${buffer} * ${BUFC_BUFFER_STRIDE}}} ${value}
    ...                         machine=${name}

Start Tx
    [Arguments]  ${name}  ${nbytes}=4
    # Fixed frame length (DFLMODE=DISABLE, FRAMELENGTH=nbytes-1) sent from FCD0 (WORDS=nbytes-1) and BUFC buffer 0.
    Execute Command             sysbus WriteDoubleWord ${{${FRC_BLOCK_ADDRESS} + ${FRC_DFLCTRL_REG}}} 0  machine=${name}
    Execute Command             sysbus WriteDoubleWord ${{${FRC_BLOCK_ADDRESS} + ${FRC_WCNTCMP0_REG}}} ${{${nbytes} - 1}}  machine=${name}
    ${fcd}=                     Set Variable  ${{(${nbytes} - 1) | (0 << ${FCD_BUFFER_SHIFT})}}
    Execute Command             sysbus WriteDoubleWord ${{${FRC_BLOCK_ADDRESS} + ${FRC_FCD0_REG}}} ${fcd}  machine=${name}
    IF  ${nbytes} == 4
        Load Bufc Buffer        ${name}  0  0x11  0x22  0x33  0x44
    ELSE
        Write Bufc Register     ${name}  0  ${BUFC_BUF0_CTRL_REG}  ${BUFC_SIZE_256}
        Load Bufc Buffer        ${name}  0  @{{["0x11"] * ${nbytes}}}
    END
    Execute Command             emulation RunFor "0.0001"
    Force State                 ${name}  ${RAC_FORCESTATE_TX}

Frame Should Be Received
    [Arguments]  ${prefix}=${SYNC_PREFIX}
    Wait For Log Entry          Received at .*: ${prefix}-11-22-33-44  treatAsRegex=true

Frame Should Not Be Received
    Should Not Be In Log        Received at

On Channel Rx From Tx Start Succeeds Without Collision
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Be Received
    Should Not Be In Log        RX already ongoing - collision

Matching Custom Sync Word Succeeds
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Configure Sync Word         tx  ${MODEM_SYNC_CUSTOM}
    Configure Sync Word         rx  ${MODEM_SYNC_CUSTOM}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Be Received    ${SYNC_PREFIX_CUSTOM}

Off Channel Receiver Does Not Receive
    [Arguments]  ${model}
    Create Wireless Pair        ${model}  rx_channel=${SYNTH_FREQ_CHANNEL_B}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Not Be Received

Receiver Idle During Transmission Does Not Receive
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Not Be Received

Incompatible Coding Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Select Linecode Phy         rx
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping: (incompatible PHY  timeout=1
    Frame Should Not Be Received

Incompatible Data Rate Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Configure Phy               rx  ${MODULATOR_TXBR_HALF}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping: (incompatible PHY  timeout=1
    Frame Should Not Be Received

Sync Word Mismatch Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Configure Sync Word         tx  ${MODEM_SYNC_CUSTOM}
    Configure Sync Word         rx  0x00
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping (SYNC MISMATCH)  timeout=1
    Frame Should Not Be Received

Enter RxSearch After Transmission Completes Does Not Receive
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Start Tx                    tx
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Execute Command             emulation RunFor "0.001"
    Frame Should Not Be Received

Retune During Preamble Succeeds
    [Arguments]  ${model}
    Create Wireless Pair        ${model}  rx_channel=${SYNTH_FREQ_CHANNEL_B}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
    Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Be Received

Retune Late In Preamble Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}  rx_channel=${SYNTH_FREQ_CHANNEL_B}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_LATE_IN_PREAMBLE}"
    Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping.*insufficient preamble  timeout=1  treatAsRegex=true
    Frame Should Not Be Received

Retune After Sync Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}  rx_channel=${SYNTH_FREQ_CHANNEL_B}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_AFTER_SYNC}"
    Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_A}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping.*insufficient preamble  timeout=1  treatAsRegex=true
    Frame Should Not Be Received

Enter RxSearch Mid Preamble Succeeds
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Frame Should Be Received

Retune Away Before Sync Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
    Tune Channel                rx  ${SYNTH_FREQ_CHANNEL_B}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping (retuned away before sync)  timeout=1
    Frame Should Not Be Received

Tx Abort During Preamble Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
    Force State                 tx  ${RAC_FORCESTATE_OFF}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping (TX was aborted)  timeout=1
    Frame Should Not Be Received

Tx Abort During Payload Drops
    [Arguments]  ${model}
    Create Wireless Pair        ${model}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx  ${LONG_FRAME_BYTES}
    Execute Command             emulation RunFor "${JOIN_AFTER_SYNC}"
    Force State                 tx  ${RAC_FORCESTATE_OFF}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          Dropping (TX was aborted)  timeout=1
    Frame Should Not Be Received

Second Transmitter Collides With Ongoing Rx
    [Arguments]  ${model}
    Create Wireless Triple      ${model}
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Start Tx                    tx
    Execute Command             emulation RunFor "${JOIN_DURING_PREAMBLE}"
    Start Tx                    tx2
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          RX already ongoing - collision  timeout=1
    Wait For Log Entry          Dropping (PRE/SYNC COLLISION)  timeout=1
    Frame Should Not Be Received

Join While Two Packets Are On Air Drops
    [Arguments]  ${model}
    Create Wireless Triple      ${model}
    Start Tx                    tx
    Start Tx                    tx2
    Force State                 rx  ${RAC_FORCESTATE_RXSEARCH}
    Execute Command             emulation RunFor "${RX_SETTLE}"
    Wait For Log Entry          RX starting with co-channel interference already on air  timeout=1
    Wait For Log Entry          Dropping (PRE/SYNC COLLISION)  timeout=1
    Frame Should Not Be Received

*** Test Cases ***
Should Receive On Channel From Tx Start Without Collision
    [Template]                      On Channel Rx From Tx Start Succeeds Without Collision
    xg22
    xg24
    xg301

Should Receive With Matching Custom Sync Word
    [Template]                      Matching Custom Sync Word Succeeds
    xg22
    xg24
    xg301

Should Not Receive Off Channel
    [Template]                      Off Channel Receiver Does Not Receive
    xg22
    xg24
    xg301

Should Not Receive While Idle During Transmission
    [Template]                      Receiver Idle During Transmission Does Not Receive
    xg22
    xg24
    xg301

Should Drop Incompatible Coding
    [Template]                      Incompatible Coding Drops
    xg22
    xg24
    xg301

Should Drop Incompatible Data Rate
    [Template]                      Incompatible Data Rate Drops
    xg22
    xg24
    xg301

Should Drop On Sync Word Mismatch
    [Template]                      Sync Word Mismatch Drops
    xg22
    xg24
    xg301

Should Not Receive When Entering RxSearch After Transmission Completes
    [Template]                      Enter RxSearch After Transmission Completes Does Not Receive
    xg22
    xg24
    xg301

Should Receive After Retune During Preamble
    [Template]                      Retune During Preamble Succeeds
    xg22
    xg24
    xg301

Should Drop After Retune Late In Preamble
    [Template]                      Retune Late In Preamble Drops
    xg22
    xg24
    xg301

Should Drop After Retune After Sync
    [Template]                      Retune After Sync Drops
    xg22
    xg24
    xg301

Should Receive When Entering RxSearch Mid Preamble
    [Template]                      Enter RxSearch Mid Preamble Succeeds
    xg22
    xg24
    xg301

Should Drop After Retune Away Before Sync
    [Template]                      Retune Away Before Sync Drops
    xg22
    xg24
    xg301

Should Drop On Tx Abort During Preamble
    [Template]                      Tx Abort During Preamble Drops
    xg22
    xg24
    xg301

Should Drop On Tx Abort During Payload
    [Template]                      Tx Abort During Payload Drops
    xg22
    xg24
    xg301

Should Drop When Second Transmitter Collides With Ongoing Rx
    [Template]                      Second Transmitter Collides With Ongoing Rx
    xg22
    xg24
    xg301

Should Drop When Joining While Two Packets Are On Air
    [Template]                      Join While Two Packets Are On Air Drops
    xg22
    xg24
    xg301
