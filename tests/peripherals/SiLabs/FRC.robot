*** Comments ***
FRC frame assembly and disassembly tests shared by the xG22, xG24 and xG301 LPW models.

Every test programs the frame control descriptors and the BUFC buffers by hand and then drives one
direction of the FRC. The TX tests force RAC into TX and inspect the frame the model puts on air; the
RX tests inject a frame and read back the buffers the disassembler filled. Both paths complete
synchronously, so the whole suite runs without starting the emulation and the log tester default
timeout is 0.

The modulator owns sync word insertion, so an assembled frame is always prefixed with the sync word
and an injected frame has to carry that prefix for RX sync detection to match. The reset values leave
SYNCBITS and SYNC0 at zero, hence the single leading 00 byte throughout.

xG22, xG24 and xG301 share the Series 2 style FRC block and an 8-bit FCD WORDS field. Configure
LPW Model supplies the model-specific addresses, offsets and field positions.

WORDS and FRAMELENGTH are programmed as (N-1) in hardware; the keywords here take the real count and
do the conversion, so the test bodies read in words and bytes.

The RX tests hand a frame straight to the radio instead of pairing two machines. A frame is only
accepted from a transmitter registered in the interference queue, so Arm Rx Peer has the radio
transmit a throwaway frame, after which the radio can name itself as the sender. Because that leaves
plenty of virtual time between the queued transmission and the injected reception, the model delivers
the whole frame in one step inside the call, which keeps the RX tests as synchronous as the TX ones.
The PHY must be configured before Arm Rx Peer: the queue records the signature at transmit time and
reception is dropped unless it still matches.

*** Variables ***
# FRC.CTRL, FRC.IF and FRC.DFLCTRL have the same field positions on all three models.
${FRC_CTRL_TXFCDMODE_SHIFT}    4
${FRC_CTRL_RXFCDMODE_SHIFT}    6
${FRC_IF_TXUF}                 0x8
${FRC_IF_RXDONE}               0x10
${FRC_IF_WCNTCMP0}             0x200
${FRC_IF_WCNTCMP1}             0x400
${FRC_IF_WCNTCMP2}             0x800
${FRC_IF_WCNTCMP_ALL}          0xE00
# DFLMODE=SINGLEBYTE with DFLBITS=8: the whole first byte of the subframe is the length field.
${FRC_DFLCTRL_SINGLE_BYTE}     0x8001
${FRC_DFLCTRL_DFLINCLUDECRC}   0x100000
${FRC_MAXLENGTH_UNRESTRICTED}  0xFF

# TXBR resets to zero, which leaves the modelled data rate at 0 bps and makes the transmit airtime
# infinite. Any non-zero setting will do; these give roughly 1 Mbps. Series 3 divides TXBRNUM by 2^16
# while Series 2 uses the TXBRNUM / TXBRDEN pair.
${SERIES_3_TXBR_VALUE}         0xD20D

# The CRC block is mocked and emits CRCWIDTH+1 zero bytes; CRCWIDTH resets to a one byte CRC.
${MOCKED_CRC_BYTE}             00

# BUFC buffers reset to 64 bytes and wrap beyond that. BUFn_CTRL.SIZE=3 selects 512 bytes, enough for
# a frame longer than the 8-bit WORDS field can express. Such buffers get their own RAM area, since
# the default 0x100 per-buffer spacing used by Load Bufc Buffer would overlap the next buffer.
${BUFC_SIZE_512}               0x3
${LARGE_BUFFER_RAM_OFFSET}     0x1000
${LARGE_BUFFER_RAM_STRIDE}     0x400
# One more byte than the 8-bit WORDS field can describe as (WORDS+1). An unlimited subframe has to
# carry all of it, while a 256-word cap would split it and insert a CRC before the last byte.
${FRAME_BEYOND_8BIT_WORDS}     257
# The reset value of the modulator sync word, in the two forms the tests need: the log spells the
# frame out as dash separated hex bytes, while an injected frame is built from numeric literals.
${SYNC_PREFIX}                 00
${SYNC_PREFIX_BYTE}            0x00

# RAC.FORCESTATE sits at the same offset on all three models, and so does RXSEARCH, state 2 of the
# radio state machine. The TX state differs, so it comes from Configure LPW Model.
${RAC_FORCESTATE_REG}          0x0018
${RAC_FORCESTATE_RXSEARCH}     0x2

# MODEM_CTRL1.SYNCDATA and MODEM_CTRL0.CODING sit at the same bits on all three models; only the
# register offsets move. CODING=LINECODE is the BLE LE Coded (long range) PHY.
${MODEM_CTRL1_SYNCDATA_BIT}    11
${MODEM_CTRL0_CODING_SHIFT}    4
${MODEM_CODING_LINECODE}       3

# The RX descriptors are the second pair of FCDs, so the RX tests leave FCD0, FCD1 and their buffers
# to Arm Rx Peer and take FCD2 and FCD3 with a buffer each.
${FIRST_RX_DESCRIPTOR}         2
${SECOND_RX_DESCRIPTOR}        3
${FIRST_RX_BUFFER}             2
${SECOND_RX_BUFFER}            3

*** Keywords ***
Configure LPW Model
    [Arguments]  ${model}
    IF  '${model}' == 'xg22'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd4182a.repl
        Configure Series 2 Registers
        Set Suite Variable     ${FRC_FCD0_REG}              0x0104
        Set Suite Variable     ${MODEM_CTRL0_REG}           0x0020
        Set Suite Variable     ${MODEM_CTRL1_REG}           0x0024
    ELSE IF  '${model}' == 'xg24'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd4186c.repl
        Configure Series 2 Registers
        Set Suite Variable     ${FRC_FCD0_REG}              0x0108
        Set Suite Variable     ${MODULATOR_TXBR_REG}        0x0068
        Set Suite Variable     ${MODEM_CTRL0_REG}           0x004C
        Set Suite Variable     ${MODEM_CTRL1_REG}           0x0050
    ELSE IF  '${model}' == 'xg301'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd1019a.repl
        Configure Series 2 Registers
        Set Suite Variable     ${FRC_BLOCK_ADDRESS}         0xA0204000
        Set Suite Variable     ${RAC_BLOCK_ADDRESS}         0xA0220000
        Set Suite Variable     ${BUFC_BLOCK_ADDRESS}        0xA0300000
        Set Suite Variable     ${MODULATOR_BLOCK_ADDRESS}   0xA0214000
        Set Suite Variable     ${MODULATOR_TXBR_REG}        0x0078
        Set Suite Variable     ${MODULATOR_TXBR_VALUE}      ${SERIES_3_TXBR_VALUE}
        Set Suite Variable     ${RAC_FORCESTATE_TX}         0x6
        Set Suite Variable     ${FRC_FCD0_REG}              0x0110
        Set Suite Variable     ${MODEM_CTRL0_REG}           0x005C
        Set Suite Variable     ${MODEM_CTRL1_REG}           0x0060
    ELSE
        Fail                   Unsupported LPW model: ${model}
    END

Configure Series 2 Registers
    Set Suite Variable         ${FRC_BLOCK_ADDRESS}         0xB8004000
    Set Suite Variable         ${RAC_BLOCK_ADDRESS}         0xB8020000
    Set Suite Variable         ${BUFC_BLOCK_ADDRESS}        0xBA000000
    # Series 2 keeps the baud rate and the PHY controls together in the MODEM block, which is what
    # MODULATOR_BLOCK_ADDRESS points at here.
    Set Suite Variable         ${MODULATOR_BLOCK_ADDRESS}   0xB8014000
    Set Suite Variable         ${BUFC_RAM_ADDRESS}          0x20000000
    Set Suite Variable         ${RAC_FORCESTATE_TX}         0x9
    # Series 2 derives the baud rate from HFXO / (8 * TXBRNUM / TXBRDEN).
    Set Suite Variable         ${MODULATOR_TXBR_VALUE}      0x000A0030
    Set Suite Variable         ${FRC_DFLCTRL_REG}           0x000C
    Set Suite Variable         ${FRC_MAXLENGTH_REG}         0x0010
    Set Suite Variable         ${FRC_WCNT_REG}              0x001C
    Set Suite Variable         ${FRC_WCNTCMP0_REG}          0x0020
    Set Suite Variable         ${FRC_WCNTCMP1_REG}          0x0024
    Set Suite Variable         ${FRC_WCNTCMP2_REG}          0x0028
    Set Suite Variable         ${FRC_CTRL_REG}              0x0048
    Set Suite Variable         ${FRC_IF_REG}                0x0068
    Set Suite Variable         ${FRC_IEN_REG}               0x006C
    Set Suite Variable         ${FCD_BUFFER_SHIFT}          8
    Set Suite Variable         ${FCD_INCLUDECRC_BIT}        10
    Set Suite Variable         ${FCD_CALCCRC_BIT}           11
    Set Suite Variable         ${FCD_EXCLUDESUBFRAMEWCNT_BIT}  16
    # WORDS is 8 bits wide, so 0x100 words selects the unlimited subframe encoding 0xFF.
    Set Suite Variable         ${FCD_UNLIMITED_WORDS}       0x100
    Set Suite Variable         ${MODULATOR_TXBR_REG}        0x0058
    Set Suite Variable         ${BUFC_BUF0_CTRL_REG}        0x000C
    Set Suite Variable         ${BUFC_BUF0_ADDR_REG}        0x0010
    Set Suite Variable         ${BUFC_BUF0_WRITEOFFSET_REG}  0x0014
    Set Suite Variable         ${BUFC_BUF0_READOFFSET_REG}  0x0018
    Set Suite Variable         ${BUFC_BUFFER_STRIDE}        0x40

Create Machine
    [Arguments]  ${model}
    Configure LPW Model         ${model}
    Reset Emulation
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescription @${PLATFORM_FILE}
    Execute Command             cpu IsHalted true
    # Forcing TX and injecting a received frame both complete synchronously, so nothing has to wait
    # for the log.
    Create Log Tester           0
    Execute Command             logLevel 1
    Execute Command             sysbus WriteDoubleWord ${{${MODULATOR_BLOCK_ADDRESS} + ${MODULATOR_TXBR_REG}}} ${MODULATOR_TXBR_VALUE}

Read Frc Register
    [Arguments]  ${offset}
    ${reg_val}=                 Execute Command  sysbus ReadDoubleWord ${{${FRC_BLOCK_ADDRESS} + ${offset}}}
    RETURN                      ${reg_val}

Write Frc Register
    [Arguments]  ${offset}  ${value}
    Execute Command             sysbus WriteDoubleWord ${{${FRC_BLOCK_ADDRESS} + ${offset}}} ${value}

Write Bufc Register
    [Arguments]  ${buffer}  ${offset}  ${value}
    Execute Command             sysbus WriteDoubleWord ${{${BUFC_BLOCK_ADDRESS} + ${offset} + ${buffer} * ${BUFC_BUFFER_STRIDE}}} ${value}

Load Bufc Buffer
    [Documentation]    Copy bytes into RAM and point a BUFC buffer at them with all of them readable.
    [Arguments]  ${buffer}  @{bytes}
    ${ram_address}=             Set Variable  ${{${BUFC_RAM_ADDRESS} + ${buffer} * 0x100}}
    FOR  ${i}  ${byte}  IN ENUMERATE  @{bytes}
        Execute Command         sysbus WriteByte ${{${ram_address} + ${i}}} ${byte}
    END
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_ADDR_REG}  ${ram_address}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_READOFFSET_REG}  0
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  ${{len($bytes)}}

Counting Pattern
    [Documentation]    ${nbytes} bytes counting up from one and wrapping after 0xFF, as the dash
    ...                separated hex string the frame log and Rx Buffer Should Contain use. Starting
    ...                at one keeps byte 256 (0x01) distinct from the mocked CRC byte, so a subframe
    ...                wrongly capped at 256 words cannot hide behind a CRC that happens to match.
    [Arguments]  ${nbytes}
    RETURN                      ${{'-'.join('%02X' % ((i + 1) & 0xFF) for i in range(${nbytes}))}}

Configure Large Bufc Buffer
    [Documentation]    Widen a BUFC buffer to 512 bytes and point it at its own RAM area, empty.
    [Arguments]  ${buffer}
    ${ram_address}=             Set Variable  ${{${BUFC_RAM_ADDRESS} + ${LARGE_BUFFER_RAM_OFFSET} + ${buffer} * ${LARGE_BUFFER_RAM_STRIDE}}}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_CTRL_REG}  ${BUFC_SIZE_512}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_ADDR_REG}  ${ram_address}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_READOFFSET_REG}  0
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  0
    RETURN                      ${ram_address}

Load Large Bufc Buffer With Counting Pattern
    [Documentation]    Fill a 512-byte BUFC buffer with ${nbytes} bytes of Counting Pattern.
    [Arguments]  ${buffer}  ${nbytes}
    ${ram_address}=             Configure Large Bufc Buffer  ${buffer}
    Execute Python              for i in range(${nbytes}): self.Machine.SystemBus.WriteByte(${ram_address} + i, (i + 1) & 0xFF)
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  ${nbytes}

Write Frame Descriptor
    [Documentation]    Program FCD ${index}. ${words} is the real word count, WORDS holds it minus one.
    [Arguments]  ${index}  ${words}  ${buffer}  ${include_crc}=${False}  ${calculate_crc}=${False}  ${exclude_from_wcnt}=${False}
    ${crc}=                     Set Variable  ${{(${include_crc} << ${FCD_INCLUDECRC_BIT}) | (${calculate_crc} << ${FCD_CALCCRC_BIT})}}
    ${value}=                   Set Variable  ${{(${words} - 1) | (${buffer} << ${FCD_BUFFER_SHIFT}) | ${crc}}}
    Write Frc Register          ${{${FRC_FCD0_REG} + 4 * ${index}}}
    ...                         ${{${value} | (${exclude_from_wcnt} << ${FCD_EXCLUDESUBFRAMEWCNT_BIT})}}

Set ${direction:(Tx|Rx)} Frame Descriptor Mode
    [Documentation]    TXFCDMODE and RXFCDMODE share FRC.CTRL, so both are set in place.
    [Arguments]  ${mode}
    ${shift}=                   Set Variable  ${{${FRC_CTRL_TXFCDMODE_SHIFT} if '${direction}' == 'Tx' else ${FRC_CTRL_RXFCDMODE_SHIFT}}}
    ${current}=                 Read Frc Register  ${FRC_CTRL_REG}
    Write Frc Register          ${FRC_CTRL_REG}  ${{(int($current.strip(), 16) & ~(0x3 << ${shift})) | (${mode} << ${shift})}}

Configure Fixed Frame Length
    [Documentation]    DFLMODE=DISABLE, so FRAMELENGTH alone bounds the frame. WCNTCMP0 is the
    ...                register holding FRAMELENGTH, so it doubles as word counter compare 0.
    [Arguments]  ${bytes}
    Write Frc Register          ${FRC_DFLCTRL_REG}  0
    Write Frc Register          ${FRC_WCNTCMP0_REG}  ${{${bytes} - 1}}

Configure Dynamic Frame Length
    [Documentation]    Take the frame length from the first byte of the leading subframe's buffer.
    [Arguments]  ${include_crc}=${False}
    Write Frc Register          ${FRC_DFLCTRL_REG}
    ...                         ${{${FRC_DFLCTRL_SINGLE_BYTE} | (${FRC_DFLCTRL_DFLINCLUDECRC} if ${include_crc} else 0)}}
    Write Frc Register          ${FRC_MAXLENGTH_REG}  ${FRC_MAXLENGTH_UNRESTRICTED}

Configure Word Counter Compares
    [Documentation]    WCNTCMP1 is LENGTHFIELDLOC and WCNTCMP2 is ADDRFIELDLOC.
    [Arguments]  ${length_field_location}  ${address_field_location}
    Write Frc Register          ${FRC_WCNTCMP1_REG}  ${length_field_location}
    Write Frc Register          ${FRC_WCNTCMP2_REG}  ${address_field_location}

Enable Sync Word In Data Stream
    [Documentation]    MODEM_CTRL1.SYNCDATA: the sync word is carried inside the data stream, which is
    ...                what puts a dedicated leading sync descriptor in front of the payload.
    ${addr}=                    Set Variable  ${{${MODULATOR_BLOCK_ADDRESS} + ${MODEM_CTRL1_REG}}}
    ${current}=                 Execute Command  sysbus ReadDoubleWord ${addr}
    Execute Command             sysbus WriteDoubleWord ${addr} ${{int($current.strip(), 16) | (1 << ${MODEM_CTRL1_SYNCDATA_BIT})}}

Select Ble Le Coded Phy
    [Documentation]    MODEM_CTRL0.CODING=LINECODE. On this PHY the FRC generates the access address
    ...                itself, which is the other way hardware marks a leading sync descriptor.
    ${addr}=                    Set Variable  ${{${MODULATOR_BLOCK_ADDRESS} + ${MODEM_CTRL0_REG}}}
    ${current}=                 Execute Command  sysbus ReadDoubleWord ${addr}
    ${cleared}=                 Set Variable  ${{int($current.strip(), 16) & ~(0x3 << ${MODEM_CTRL0_CODING_SHIFT})}}
    Execute Command             sysbus WriteDoubleWord ${addr} ${{${cleared} | (${MODEM_CODING_LINECODE} << ${MODEM_CTRL0_CODING_SHIFT})}}

Force Tx
    Execute Command             sysbus WriteDoubleWord ${{${RAC_BLOCK_ADDRESS} + ${RAC_FORCESTATE_REG}}} ${RAC_FORCESTATE_TX}

Frame Should Be Sent
    [Documentation]    The assembled frame is the last field of the "Sending frame" log entry.
    [Arguments]  ${payload}
    Wait For Log Entry          Sending frame.*: ${SYNC_PREFIX}-${payload}$  treatAsRegex=true

No Frame Should Be Sent
    Should Not Be In Log        Sending frame

Prepare Rx Buffer
    [Documentation]    Point a BUFC buffer at empty RAM so the disassembled frame can be read back.
    [Arguments]  ${buffer}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_ADDR_REG}  ${{${BUFC_RAM_ADDRESS} + ${buffer} * 0x100}}
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_READOFFSET_REG}  0
    Write Bufc Register         ${buffer}  ${BUFC_BUF0_WRITEOFFSET_REG}  0

Arm Rx Peer
    [Documentation]    Register this radio in the interference queue as its own future RX peer by
    ...                transmitting a throwaway frame. The transmission must not land on virtual time
    ...                zero, because TimeInterval.Empty is zero ticks and a queue entry stamped zero
    ...                reads back as "no entry". The second run leaves enough slack that the injected
    ...                reception completes in a single step. Call this after the PHY is set up and
    ...                before the RX programming, since it leaves FRAMELENGTH, FCD0 and buffer 0 set
    ...                up for its own transmission.
    Execute Command             emulation RunFor "0.001"
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  4  0
    Load Bufc Buffer            0  0xDE  0xAD  0xBE  0xEF
    Force Tx
    Execute Command             emulation RunFor "0.005"
    # Drop the transmit flags so the RX assertions start from a clean FRC.IF.
    Write Frc Register          ${FRC_IF_REG}  0

Inject Received Frame
    [Documentation]    Hand a frame to the radio as if the demodulator had just received it. The
    ...                modulator owns sync word insertion, so the frame carries the sync word prefix
    ...                that RX sync detection expects and the FRC then skips.
    [Arguments]  @{payload}
    Execute Command             sysbus WriteDoubleWord ${{${RAC_BLOCK_ADDRESS} + ${RAC_FORCESTATE_REG}}} ${RAC_FORCESTATE_RXSEARCH}
    ${bytes}=                   Catenate  SEPARATOR=,  ${SYNC_PREFIX_BYTE}  @{payload}
    Execute Python              radio = self.Machine['sysbus.radio']; radio.ReceiveFrame(System.Array[System.Byte]([${bytes}]), radio)

Frame Should Be Received
    [Documentation]    The frame handed to the model is echoed by the "Received at" log entry.
    Wait For Log Entry          Received at .*: ${SYNC_PREFIX}-  treatAsRegex=true

Rx Buffer Should Contain
    [Documentation]    Read back the bytes the disassembler wrote into a BUFC buffer, starting at the
    ...                RAM address the buffer was pointed at. The buffer's write offset gives their
    ...                count, since Prepare Rx Buffer and Configure Large Bufc Buffer left it at zero.
    [Arguments]  ${buffer}  ${expected}
    ${buffer_regs}=             Set Variable  ${{${BUFC_BLOCK_ADDRESS} + ${buffer} * ${BUFC_BUFFER_STRIDE}}}
    ${ram}=                     Execute Command  sysbus ReadDoubleWord ${{${buffer_regs} + ${BUFC_BUF0_ADDR_REG}}}
    ${length}=                  Execute Command  sysbus ReadDoubleWord ${{${buffer_regs} + ${BUFC_BUF0_WRITEOFFSET_REG}}}
    ${actual}=                  Execute Python  '-'.join('%02X' % self.Machine.SystemBus.ReadByte(${ram} + i) for i in range(${length}))
    Should Be Equal             ${actual}  ${expected}

Frc Interrupt Flags Should Be ${state:(Set|Clear)}
    [Arguments]  ${mask}
    ${flags}=                   Read Frc Register  ${FRC_IF_REG}
    Should Be Equal As Integers  ${{int($flags.strip(), 16) & ${mask}}}  ${{${mask} if '${state}' == 'Set' else 0}}

Word Counter Should Be
    [Arguments]  ${expected}
    ${wcnt}=                    Read Frc Register  ${FRC_WCNT_REG}
    Should Be Equal As Integers  ${wcnt}  ${expected}

Frc Assembles A Fixed Length Frame From One Descriptor
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  4  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frame Should Be Sent        11-22-33-44
    Word Counter Should Be      4
    Frc Interrupt Flags Should Be Clear  ${FRC_IF_TXUF}

Frc Reuses The Same Tx Descriptor In Fcd Mode 0
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  0
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  2  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frame Should Be Sent        11-22-33-44
    Word Counter Should Be      4

Frc Alternates Tx Descriptors In Fcd Mode 1
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  1
    Configure Fixed Frame Length  8
    Write Frame Descriptor      0  2  0
    Write Frame Descriptor      1  2  1
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44
    Load Bufc Buffer            1  0xAA  0xBB  0xCC  0xDD

    Force Tx

    Frame Should Be Sent        11-22-AA-BB-33-44-CC-DD
    Word Counter Should Be      8

Frc Uses The Leading Tx Descriptor Once In Fcd Mode 2
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  2
    Configure Fixed Frame Length  6
    Write Frame Descriptor      0  2  0
    Write Frame Descriptor      1  2  1
    Load Bufc Buffer            0  0x11  0x22
    Load Bufc Buffer            1  0xAA  0xBB  0xCC  0xDD

    Force Tx

    Frame Should Be Sent        11-22-AA-BB-CC-DD
    Word Counter Should Be      6

Frc Starts The Frame At The First Descriptor Holding Data
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  2
    Configure Dynamic Frame Length
    Write Frame Descriptor      0  1  0
    Write Frame Descriptor      1  ${FCD_UNLIMITED_WORDS}  1
    Load Bufc Buffer            1  0x03  0xAA  0xBB  0xCC

    Force Tx

    Frame Should Be Sent        03-AA-BB-CC
    Word Counter Should Be      4
    Frc Interrupt Flags Should Be Clear  ${FRC_IF_TXUF}

Frc Appends The Crc When Include Crc Is Set
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  4  0  include_crc=${True}
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frame Should Be Sent        11-22-33-44-${MOCKED_CRC_BYTE}
    Word Counter Should Be      4

Frc Appends No Crc When Only Calculate Crc Is Set
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  4  0  calculate_crc=${True}
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frame Should Be Sent        11-22-33-44
    Word Counter Should Be      4

Frc Sends An Unlimited Subframe Longer Than The Words Field As One Subframe
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  ${FRAME_BEYOND_8BIT_WORDS}
    Write Frame Descriptor      0  ${FCD_UNLIMITED_WORDS}  0  include_crc=${True}
    Load Large Bufc Buffer With Counting Pattern  0  ${FRAME_BEYOND_8BIT_WORDS}
    ${payload}=                 Counting Pattern  ${FRAME_BEYOND_8BIT_WORDS}

    Force Tx
    # Unlike the few-byte frames of the other TX tests, this one takes a measurable airtime, so the
    # transmission has to run to completion. Otherwise it stays on air in the interference queue,
    # which is shared by every machine in this Renode instance, and collides with the RX tests below.
    Execute Command             emulation RunFor "0.005"

    Frame Should Be Sent        ${payload}-${MOCKED_CRC_BYTE}
    Word Counter Should Be      ${FRAME_BEYOND_8BIT_WORDS}
    Frc Interrupt Flags Should Be Clear  ${FRC_IF_TXUF}

Frc Reserves The Crc Out Of A Dynamic Frame Length
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Dynamic Frame Length  include_crc=${True}
    Write Frame Descriptor      0  ${FCD_UNLIMITED_WORDS}  0  include_crc=${True}
    Load Bufc Buffer            0  0x04  0xAA  0xBB  0xCC

    Force Tx

    Frame Should Be Sent        04-AA-BB-CC-${MOCKED_CRC_BYTE}
    Word Counter Should Be      5

Frc Raises Every Word Counter Compare Crossed By The Frame
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Configure Word Counter Compares  2  4
    Write Frc Register          ${FRC_IEN_REG}  ${FRC_IF_WCNTCMP_ALL}
    Write Frame Descriptor      0  4  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frc Interrupt Flags Should Be Set  ${FRC_IF_WCNTCMP_ALL}
    ${irqState}=                Execute Command  radio FrameControllerIRQ
    Should Contain              ${irqState}  GPIO: set

Frc Leaves A Word Counter Compare Beyond The Frame Clear
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Configure Word Counter Compares  2  0x20
    Write Frame Descriptor      0  4  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frc Interrupt Flags Should Be Set  ${FRC_IF_WCNTCMP0}
    Frc Interrupt Flags Should Be Set  ${FRC_IF_WCNTCMP1}
    Frc Interrupt Flags Should Be Clear  ${FRC_IF_WCNTCMP2}

Frc Raises A Word Counter Compare Of Zero At The Start Of The Frame
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  4
    Configure Word Counter Compares  0  0
    Write Frame Descriptor      0  4  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frc Interrupt Flags Should Be Set  ${FRC_IF_WCNTCMP1}
    Frc Interrupt Flags Should Be Set  ${FRC_IF_WCNTCMP2}

Frc Keeps An Excluded Subframe Out Of The Word Counter
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  2
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  2  0  exclude_from_wcnt=${True}
    Write Frame Descriptor      1  ${FCD_UNLIMITED_WORDS}  1
    Load Bufc Buffer            0  0xEE  0xFF
    Load Bufc Buffer            1  0xAA  0xBB  0xCC  0xDD

    Force Tx

    Frame Should Be Sent        EE-FF-AA-BB-CC-DD
    Word Counter Should Be      4

Frc Counts An Excluded Subframe Programmed With Unlimited Words
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  2
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  ${FCD_UNLIMITED_WORDS}  0  exclude_from_wcnt=${True}
    Write Frame Descriptor      1  ${FCD_UNLIMITED_WORDS}  1
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Wait For Log Entry          FCD0 sets EXCLUDESUBFRAMEWCNT together with an unlimited WORDS
    Frame Should Be Sent        11-22-33-44
    Word Counter Should Be      4

Frc Aborts When The Fcd Mode Never Advances Past An Excluded Subframe
    [Arguments]  ${model}
    Create Machine              ${model}
    Set Tx Frame Descriptor Mode  0
    Configure Fixed Frame Length  4
    Write Frame Descriptor      0  2  0  exclude_from_wcnt=${True}
    Load Bufc Buffer            0  0x11  0x22

    Force Tx

    Wait For Log Entry          FCD0 is excluded from WCNT but the FCD mode never advances past it
    No Frame Should Be Sent

Frc Reports An Underflow When The Buffer Runs Dry Mid Frame
    [Arguments]  ${model}
    Create Machine              ${model}
    Configure Fixed Frame Length  8
    Write Frame Descriptor      0  ${FCD_UNLIMITED_WORDS}  0
    Load Bufc Buffer            0  0x11  0x22  0x33  0x44

    Force Tx

    Frc Interrupt Flags Should Be Set  ${FRC_IF_TXUF}
    No Frame Should Be Sent

Frc Disassembles A Fixed Length Frame Into One Descriptor
    [Arguments]  ${model}
    Create Machine              ${model}
    Arm Rx Peer
    Configure Fixed Frame Length  4
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  4  ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0x33  0x44

    Frame Should Be Received
    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  11-22-33-44
    Word Counter Should Be      4
    Frc Interrupt Flags Should Be Set  ${FRC_IF_RXDONE}

Frc Alternates Rx Descriptors In Fcd Mode 1
    [Arguments]  ${model}
    Create Machine              ${model}
    Arm Rx Peer
    Set Rx Frame Descriptor Mode  1
    Configure Fixed Frame Length  8
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  2  ${FIRST_RX_BUFFER}
    Write Frame Descriptor      ${SECOND_RX_DESCRIPTOR}  2  ${SECOND_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${SECOND_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0xAA  0xBB  0x33  0x44  0xCC  0xDD

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  11-22-33-44
    Rx Buffer Should Contain    ${SECOND_RX_BUFFER}  AA-BB-CC-DD
    Word Counter Should Be      8

Frc Uses The Leading Rx Descriptor Once In Fcd Mode 2
    [Arguments]  ${model}
    Create Machine              ${model}
    Arm Rx Peer
    Set Rx Frame Descriptor Mode  2
    Configure Fixed Frame Length  6
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  2  ${FIRST_RX_BUFFER}
    Write Frame Descriptor      ${SECOND_RX_DESCRIPTOR}  2  ${SECOND_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${SECOND_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0xAA  0xBB  0xCC  0xDD

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  11-22
    Rx Buffer Should Contain    ${SECOND_RX_BUFFER}  AA-BB-CC-DD
    Word Counter Should Be      6

Frc Receives An Unlimited Subframe Longer Than The Words Field Into One Buffer
    [Arguments]  ${model}
    Create Machine              ${model}
    Arm Rx Peer
    Configure Fixed Frame Length  ${FRAME_BEYOND_8BIT_WORDS}
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  ${FCD_UNLIMITED_WORDS}  ${FIRST_RX_BUFFER}  include_crc=${True}
    Configure Large Bufc Buffer  ${FIRST_RX_BUFFER}
    ${expected}=                Counting Pattern  ${FRAME_BEYOND_8BIT_WORDS}

    Inject Received Frame       @{{[(i + 1) & 0xFF for i in range(${FRAME_BEYOND_8BIT_WORDS})]}}  0x00

    Frame Should Be Received
    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  ${expected}
    Word Counter Should Be      ${FRAME_BEYOND_8BIT_WORDS}
    Frc Interrupt Flags Should Be Set  ${FRC_IF_RXDONE}

Frc Takes The Received Frame Length From The Length Field
    [Arguments]  ${model}
    Create Machine              ${model}
    Arm Rx Peer
    Configure Dynamic Frame Length
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  ${FCD_UNLIMITED_WORDS}  ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}

    Inject Received Frame       0x04  0xAA  0xBB  0xCC

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  04-AA-BB-CC
    Word Counter Should Be      4

Frc Skips A Leading Rx Descriptor Excluded From The Word Counter
    [Arguments]  ${model}
    Create Machine              ${model}
    Enable Sync Word In Data Stream
    Arm Rx Peer
    Set Rx Frame Descriptor Mode  2
    Configure Fixed Frame Length  4
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  1  ${FIRST_RX_BUFFER}  exclude_from_wcnt=${True}
    Write Frame Descriptor      ${SECOND_RX_DESCRIPTOR}  4  ${SECOND_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${SECOND_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0x33  0x44

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  ${EMPTY}
    Rx Buffer Should Contain    ${SECOND_RX_BUFFER}  11-22-33-44
    Word Counter Should Be      4

Frc Skips A Leading Rx Descriptor On The Ble Le Coded Phy
    [Arguments]  ${model}
    Create Machine              ${model}
    Select Ble Le Coded Phy
    Enable Sync Word In Data Stream
    Arm Rx Peer
    Set Rx Frame Descriptor Mode  2
    Configure Fixed Frame Length  4
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  1  ${FIRST_RX_BUFFER}
    Write Frame Descriptor      ${SECOND_RX_DESCRIPTOR}  4  ${SECOND_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${SECOND_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0x33  0x44

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  ${EMPTY}
    Rx Buffer Should Contain    ${SECOND_RX_BUFFER}  11-22-33-44
    Word Counter Should Be      4

Frc Keeps A Leading Rx Descriptor That Marks No Sync Word
    [Arguments]  ${model}
    Create Machine              ${model}
    Enable Sync Word In Data Stream
    Arm Rx Peer
    Set Rx Frame Descriptor Mode  2
    Configure Fixed Frame Length  4
    Write Frame Descriptor      ${FIRST_RX_DESCRIPTOR}  1  ${FIRST_RX_BUFFER}
    Write Frame Descriptor      ${SECOND_RX_DESCRIPTOR}  4  ${SECOND_RX_BUFFER}
    Prepare Rx Buffer           ${FIRST_RX_BUFFER}
    Prepare Rx Buffer           ${SECOND_RX_BUFFER}

    Inject Received Frame       0x11  0x22  0x33  0x44

    Rx Buffer Should Contain    ${FIRST_RX_BUFFER}  11
    Rx Buffer Should Contain    ${SECOND_RX_BUFFER}  22-33-44
    Word Counter Should Be      4

*** Test Cases ***
Should Assemble A Fixed Length Frame From One Descriptor
    [Template]                      Frc Assembles A Fixed Length Frame From One Descriptor
    xg22
    xg24
    xg301

Should Reuse The Same Tx Descriptor In Fcd Mode 0
    [Documentation]    Mode 0 keeps returning to FCD0, so a two word descriptor emits the frame in
    ...                two subframes.
    [Template]                      Frc Reuses The Same Tx Descriptor In Fcd Mode 0
    xg22
    xg24
    xg301

Should Alternate Tx Descriptors In Fcd Mode 1
    [Documentation]    Mode 1 alternates FCD0 and FCD1 from the second subframe onwards, so the frame
    ...                interleaves both buffers. Catches an off-by-one that would start on FCD0 twice.
    [Template]                      Frc Alternates Tx Descriptors In Fcd Mode 1
    xg22
    xg24
    xg301

Should Use The Leading Tx Descriptor Once In Fcd Mode 2
    [Documentation]    Mode 2 takes FCD0 for the first subframe and FCD1 for every subframe after it.
    [Template]                      Frc Uses The Leading Tx Descriptor Once In Fcd Mode 2
    xg22
    xg24
    xg301

Should Start The Frame At The First Descriptor Holding Data
    [Documentation]    A PHY may point the leading FCD at a buffer the stack never fills, leaving both
    ...                the payload and the dynamic length field in the next descriptor's buffer.
    ...                Assembly has to skip that descriptor instead of decoding the length from, and
    ...                underflowing on, the empty buffer.
    [Template]                      Frc Starts The Frame At The First Descriptor Holding Data
    xg22
    xg24
    xg301

Should Append The Crc When Include Crc Is Set
    [Documentation]    INCLUDECRC is the bit that inserts the CRC after the subframe data.
    [Template]                      Frc Appends The Crc When Include Crc Is Set
    xg22
    xg24
    xg301

Should Append No Crc When Only Calculate Crc Is Set
    [Documentation]    CALCCRC only feeds the CRC accumulator; on its own it must not extend the frame.
    [Template]                      Frc Appends No Crc When Only Calculate Crc Is Set
    xg22
    xg24
    xg301

Should Send An Unlimited Subframe Longer Than The Words Field As One Subframe
    [Documentation]    The unlimited WORDS encoding means "the remainder of the frame", not a
    ...                (WORDS+1) word cap. A frame longer than the widest cap the field can express
    ...                must go out as a single subframe with one CRC at the end, rather than being
    ...                split with a CRC inserted before its last bytes.
    [Template]                      Frc Sends An Unlimited Subframe Longer Than The Words Field As One Subframe
    xg22
    xg24
    xg301

Should Reserve The Crc Out Of A Dynamic Frame Length
    [Documentation]    With DFLINCLUDECRC the decoded length covers the CRC, so the subframe data has
    ...                to shrink by the CRC width instead of overrunning the frame.
    [Template]                      Frc Reserves The Crc Out Of A Dynamic Frame Length
    xg22
    xg24
    xg301

Should Raise Every Word Counter Compare Crossed By The Frame
    [Template]                      Frc Raises Every Word Counter Compare Crossed By The Frame
    xg22
    xg24
    xg301

Should Leave A Word Counter Compare Beyond The Frame Clear
    [Template]                      Frc Leaves A Word Counter Compare Beyond The Frame Clear
    xg22
    xg24
    xg301

Should Raise A Word Counter Compare Of Zero At The Start Of The Frame
    [Documentation]    A compare programmed to 0 matches as the word counter is reset, which is how
    ...                LENGTHFIELDLOC behaves when the length field is the first word of the frame.
    [Template]                      Frc Raises A Word Counter Compare Of Zero At The Start Of The Frame
    xg22
    xg24
    xg301

Should Keep An Excluded Subframe Out Of The Word Counter
    [Documentation]    EXCLUDESUBFRAMEWCNT sizes the subframe by WORDS alone and leaves the full
    ...                FRAMELENGTH budget to the descriptors that follow.
    [Template]                      Frc Keeps An Excluded Subframe Out Of The Word Counter
    xg22
    xg24
    xg301

Should Count An Excluded Subframe Programmed With Unlimited Words
    [Documentation]    An excluded subframe is bounded by WORDS alone, so the unlimited encoding would
    ...                never terminate it. The exclusion is reported and ignored, and the subframe is
    ...                counted in the word counter like any other.
    [Template]                      Frc Counts An Excluded Subframe Programmed With Unlimited Words
    xg22
    xg24
    xg301

Should Abort When The Fcd Mode Never Advances Past An Excluded Subframe
    [Documentation]    Mode 0 keeps returning to FCD0, so an excluded FCD0 leaves the word counter at
    ...                zero for every subframe. Assembly has to stop instead of looping forever.
    [Template]                      Frc Aborts When The Fcd Mode Never Advances Past An Excluded Subframe
    xg22
    xg24
    xg301

Should Report An Underflow When The Buffer Runs Dry Mid Frame
    [Documentation]    An empty buffer met once assembly is under way is a real underflow, unlike a
    ...                leading descriptor that never holds data.
    [Template]                      Frc Reports An Underflow When The Buffer Runs Dry Mid Frame
    xg22
    xg24
    xg301

Should Disassemble A Fixed Length Frame Into One Descriptor
    [Template]                      Frc Disassembles A Fixed Length Frame Into One Descriptor
    xg22
    xg24
    xg301

Should Alternate Rx Descriptors In Fcd Mode 1
    [Documentation]    Mode 1 alternates the two RX descriptors from the second subframe onwards, so a
    ...                received frame is split between both buffers.
    [Template]                      Frc Alternates Rx Descriptors In Fcd Mode 1
    xg22
    xg24
    xg301

Should Use The Leading Rx Descriptor Once In Fcd Mode 2
    [Documentation]    Mode 2 takes FCD2 for the first subframe and FCD3 for every subframe after it,
    ...                so the leading buffer only ever holds one subframe worth of payload.
    [Template]                      Frc Uses The Leading Rx Descriptor Once In Fcd Mode 2
    xg22
    xg24
    xg301

Should Receive An Unlimited Subframe Longer Than The Words Field Into One Buffer
    [Documentation]    RX counterpart of the unlimited subframe TX test: the whole payload lands in
    ...                the buffer in order, with the trailing CRC taken off the end of the frame rather than
    ...                being expected part way through the payload.
    [Template]                      Frc Receives An Unlimited Subframe Longer Than The Words Field Into One Buffer
    xg22
    xg24
    xg301

Should Take The Received Frame Length From The Length Field
    [Documentation]    With DFLMODE=SINGLEBYTE the frame length comes from the received bytes, so the
    ...                disassembler has to stop where the length field says rather than at MAXLENGTH.
    [Template]                      Frc Takes The Received Frame Length From The Length Field
    xg22
    xg24
    xg301

Should Skip A Leading Rx Descriptor Excluded From The Word Counter
    [Documentation]    With SYNCDATA the sync word travels in the data stream, so the PHY puts a
    ...                dedicated leading descriptor in front of the payload. The demodulator has
    ...                already stripped that sync word, so the descriptor must receive nothing instead
    ...                of swallowing the first payload bytes. EXCLUDESUBFRAMEWCNT is how hardware
    ...                marks it.
    [Template]                      Frc Skips A Leading Rx Descriptor Excluded From The Word Counter
    xg22
    xg24
    xg301

Should Skip A Leading Rx Descriptor On The Ble Le Coded Phy
    [Documentation]    BLE LE Coded is the second marker for a leading sync descriptor: the access
    ...                address is generated by the FRC rather than received, so the descriptor holding
    ...                it takes no payload even without EXCLUDESUBFRAMEWCNT.
    [Template]                      Frc Skips A Leading Rx Descriptor On The Ble Le Coded Phy
    xg22
    xg24
    xg301

Should Keep A Leading Rx Descriptor That Marks No Sync Word
    [Documentation]    Same descriptor layout as the two tests above but on an uncoded PHY and without
    ...                EXCLUDESUBFRAMEWCNT, so nothing marks the leading descriptor as holding the
    ...                sync word and it receives payload like any other.
    [Template]                      Frc Keeps A Leading Rx Descriptor That Marks No Sync Word
    xg22
    xg24
    xg301
