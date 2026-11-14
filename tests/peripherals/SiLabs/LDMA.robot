*** Comments ***
LDMA tests shared by the SiLabs_LDMA_0_1, SiLabs_LDMA_0_3 and SiLabs_LDMA_3_3 models. Every test
runs once per model.

The IP versions expose the same programming model with different register offsets.

The transfer tests program the channel descriptor registers directly. The write and synchronize
tests place descriptors in RAM and fetch them with LINKLOAD.

*** Variables ***
${LDMA_CTRL}                  0x2000000
${CHANNEL0}                   0
${CHANNEL1}                   1
${BOTH_CHANNELS}              0x3
${XFERCNT_0}                  0
${XFERCNT_1}                  1

# DSTMODE absolute, SRCMODE relative, DSTINC 1, SIZE BYTE, SRCINC 0, DONEIEN, REQMODE ALL
${GENERIC_CH_CTRL}            0x50310000
${CH_CTRL_0_FOR_LINK_TEST}    0xD0310000
# LINK set, with LINKADDR pointing at the linked structure written into RAM by the test
${CH_LINK_0_FOR_LINK_TEST}    0x20000002
${CH_LINK_1_FOR_LINK_TEST}    0x51
# The linked structure sets STRUCTREQ so that it runs as soon as it is fetched; enabling a channel
# alone does not start a transfer on any of the tested models.
${LINKED_TRANSFER_CTRL}       0x00300008
${LINKED_TRANSFER_SOURCE}     0x20002000
${LINKED_TRANSFER_TARGET}     0x20002100
${LINKED_TRANSFER_VALUE}      0xA5

# Descriptor control words: STRUCTTYPE in bits 1:0, DONEIEN in bit 20
${SYNC_CTRL}                  0x00000001
${SYNC_CTRL_DONEIEN}          0x00100001
${WRITE_CTRL_DONEIEN}         0x00100002

# Transfer structures used by the data path tests. All of them set STRUCTREQ, so a LINKLOAD both
# fetches and runs them on every IP version, and DONEIEN so completion is visible in IF.
# SIZE word, SRCINC and DSTINC one unit, XFERCNT four units, REQMODE ALL
${WORD_TRANSFER_CTRL}         0x08300038
# the same transfer with DSTINC NONE, so every unit lands on the same destination address
${WORD_TRANSFER_FIXED_DST_CTRL}  0x38300038
# the same four units in REQMODE BLOCK with BLOCKSIZE two units, so each request moves two
${WORD_BLOCK_TRANSFER_CTRL}   0x08110038
# a single word in REQMODE ALL
${SINGLE_WORD_TRANSFER_CTRL}  0x08300008

${TRANSFER_SOURCE}            0x20003000
${TRANSFER_TARGET}            0x20003100
${TRANSFER_WORD_0}            0x11111111
${TRANSFER_WORD_1}            0x22222222
${TRANSFER_WORD_2}            0x33333333
${TRANSFER_WORD_3}            0x44444444
${SECOND_TRANSFER_VALUE}      0x5A5A5A5A

# Descriptor locations and the target of the write immediate structures
${CH0_DESCRIPTOR_0}           0x20000000
${CH0_DESCRIPTOR_1}           0x20000010
${CH1_DESCRIPTOR_0}           0x20000020
${WRITE_TARGET}               0x20001000
${IMMEDIATE_VALUE}            0xDEADBEEF

# Bit 7 of SYNCTRIG is used by all synchronization structures below
${SYNC_TRIG_7}                0x80
# SYNCSET in bits 7:0 and SYNCCLR in bits 15:8 of the second descriptor word
${SET_TRIG_7}                 0x00000080
${CLEAR_TRIG_7}               0x00008000
# MATCHVAL and MATCHEN sit in the low two bytes of the third descriptor word, in an order that
# depends on the IP version, see Configure Descriptor Match Layout. Waiting for the trigger to be
# set puts the same value in both bytes, so it reads the same either way.
${MATCH_TRIG_7_SET}           0x00008080
${NO_MATCH}                   0x00000000
# LINK in bit 1 and LINKADDR in bits 31:2
${LINK_TO_DESCRIPTOR_1}       0x20000012
${NO_LINK}                    0x00000000

*** Keywords ***
Create Machine
    [Arguments]                ${ldma_version}
    Reset Emulation
    IF  '${ldma_version}' == '3_3'
        Configure 3_3 Platform
        Configure 3_3 Registers
        Configure Descriptor Match Layout  ${True}
    ELSE
        Configure 0_1 And 0_3 Platform  SiLabs_LDMA_${ldma_version}
        Configure 0_1 And 0_3 Registers
        Configure Descriptor Match Layout  ${False}
    END
    Execute Command            mach create "test"
    Execute Command            machine LoadPlatformDescriptionFromString ${REPL_STRING}

Configure Descriptor Match Layout
    #The versions supporting extended descriptors place MATCHEN in bits 7:0 and MATCHVAL in bits
    #15:8 of the third synchronization descriptor word, the reverse of the older controllers, as
    #declared by the sync structure in emlib em_ldma.h. Waiting for SYNCTRIG[7] to be clear is the
    #case that tells the two apart: MATCHEN is 0x80 and MATCHVAL is 0.
    [Arguments]                ${extended_descriptors}
    ${match}=  Set Variable If  ${extended_descriptors}  0x00000080  0x00008000
    Set Suite Variable         ${MATCH_TRIG_7_CLEAR}  ${match}

Configure 0_1 And 0_3 Platform
    [Arguments]                ${model}
    Set Suite Variable         ${PER_CHANNEL_IRQ}  ${False}
    ${repl}=                   Catenate  SEPARATOR=${\n}
    ...  """
    ...  ldma: DMA.${model} @ {
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40040000; size: 0x4000; region: "ldma" };
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40044000; size: 0x4000; region: "ldmaxbar" }
    ...  ${SPACE*8}}
    ...  ${EMPTY}
    ...  mem: Memory.MappedMemory @ sysbus 0x20000000
    ...  ${SPACE*4}size: 0x10000
    ...  """
    Set Suite Variable         ${REPL_STRING}  ${repl}

Configure 3_3 Platform
    Set Suite Variable         ${PER_CHANNEL_IRQ}  ${True}
    ${repl}=                   Catenate  SEPARATOR=${\n}
    ...  """
    ...  ldma: DMA.SiLabs_LDMA_3_3 @ {
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40814000; size: 0x4000; region: "ldma_ns" };
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x50814000; size: 0x4000; region: "ldma_s" };
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40844000; size: 0x4000; region: "ldmaxbar_ns" };
    ...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x50844000; size: 0x4000; region: "ldmaxbar_s" }
    ...  ${SPACE*8}}
    ...  ${EMPTY}
    ...  mem: Memory.MappedMemory @ sysbus 0x20000000
    ...  ${SPACE*4}size: 0x10000
    ...  """
    Set Suite Variable         ${REPL_STRING}  ${repl}

Configure 0_1 And 0_3 Registers
    Set Suite Variable         ${CTRL_REG}         0x0008
    Set Suite Variable         ${SYNCSWSET_REG}    0x0010
    Set Suite Variable         ${SYNCSWCLR_REG}    0x0014
    Set Suite Variable         ${SYNCSTATUS_REG}   0x0020
    Set Suite Variable         ${CHEN_REG}         0x0024
    Set Suite Variable         ${CHSTATUS_REG}     0x002C
    Set Suite Variable         ${CHBUSY_REG}       0x0030
    Set Suite Variable         ${CHDONE_REG}       0x0034
    Set Suite Variable         ${SWREQ_REG}        0x003C
    Set Suite Variable         ${REQDIS_REG}       0x0040
    Set Suite Variable         ${LINKLOAD_REG}     0x0048
    Set Suite Variable         ${IF_REG}           0x0050
    Set Suite Variable         ${IEN_REG}          0x0054
    Configure Channel Registers  0x0064  0x0070

Configure 3_3 Registers
    Set Suite Variable         ${CTRL_REG}         0x000C
    Set Suite Variable         ${SYNCSWSET_REG}    0x0014
    Set Suite Variable         ${SYNCSWCLR_REG}    0x0018
    Set Suite Variable         ${SYNCSTATUS_REG}   0x0024
    Set Suite Variable         ${CHEN_REG}         0x0028
    Set Suite Variable         ${CHSTATUS_REG}     0x0030
    Set Suite Variable         ${CHBUSY_REG}       0x0034
    Set Suite Variable         ${CHDONE_REG}       0x0038
    Set Suite Variable         ${SWREQ_REG}        0x0040
    Set Suite Variable         ${REQDIS_REG}       0x0044
    Set Suite Variable         ${LINKLOAD_REG}     0x004C
    Set Suite Variable         ${IF_REG}           0x0054
    Set Suite Variable         ${IEN_REG}          0x0058
    Configure Channel Registers  0x0078  0x0084

Configure Channel Registers
    [Arguments]                ${ch0_ctrl}  ${ch0_link}
    # Channel 1 registers follow channel 0 at a 0x30 offset
    Set Suite Variable         ${CH0_CTRL_REG}  ${ch0_ctrl}
    Set Suite Variable         ${CH0_LINK_REG}  ${ch0_link}
    Set Suite Variable         ${CH1_CTRL_REG}  ${{hex(${ch0_ctrl} + 0x30)}}
    Set Suite Variable         ${CH1_LINK_REG}  ${{hex(${ch0_link} + 0x30)}}

Write Register
    [Arguments]                 ${register}  ${value}
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${register} ${value}

Register Should Be Equal
    [Arguments]                 ${register}  ${expected}
    ${read_val}=                Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${register}
    Should Be Equal As Integers   ${read_val}  ${expected}

Memory Should Be Equal
    [Arguments]                 ${address}  ${expected}
    ${read_val}=                Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Integers   ${read_val}  ${expected}

Assert Channel IRQ Is Set
    [Arguments]                 ${channel}
    ${irqState}=                Execute Command  sysbus.ldma ${{'Channel${channel}IRQ' if ${PER_CHANNEL_IRQ} else 'IRQ'}}
    Should Contain              ${irqState}  GPIO: set

Assert Channel IRQ Is Unset
    [Arguments]                 ${channel}
    ${irqState}=                Execute Command  sysbus.ldma ${{'Channel${channel}IRQ' if ${PER_CHANNEL_IRQ} else 'IRQ'}}
    Should Contain              ${irqState}  GPIO: unset

Write Transfer Source Words
    FOR  ${index}  ${word}  IN ENUMERATE  ${TRANSFER_WORD_0}  ${TRANSFER_WORD_1}  ${TRANSFER_WORD_2}  ${TRANSFER_WORD_3}
        Execute Command         sysbus WriteDoubleWord ${{hex(${TRANSFER_SOURCE} + 4 * ${index})}} ${word}
    END

Transfer Target Word Should Be Equal
    [Arguments]                 ${index}  ${expected}
    Memory Should Be Equal      ${{hex(${TRANSFER_TARGET} + 4 * ${index})}}  ${expected}

Write Descriptor
    [Arguments]                 ${address}  ${ctrl}  ${second_word}  ${third_word}  ${link}
    FOR  ${index}  ${word}  IN ENUMERATE  ${ctrl}  ${second_word}  ${third_word}  ${link}
        Execute Command         sysbus WriteDoubleWord ${{hex(${address} + 4 * ${index})}} ${word}
    END

Link Load Channel
    [Arguments]                 ${channel}  ${descriptor}
    Write Register              ${IEN_REG}  ${BOTH_CHANNELS}
    Write Register              ${CH${channel}_LINK_REG}  ${descriptor}
    Write Register              ${LINKLOAD_REG}  ${{hex(1 << ${channel})}}

Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE
    [Arguments]                 ${channel}
    #sets NUMFIXED to 2, then programs the channel with DONEIEN and REQMODE ALL
    Write Register              ${CTRL_REG}  ${LDMA_CTRL}
    Write Register              ${CH${channel}_CTRL_REG}  ${GENERIC_CH_CTRL}

Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block
    [Arguments]                 ${channel}  ${xfercnt}
    #sets NUMFIXED to 2, then programs the channel with DONEIEN, REQMODE BLOCK, BLOCKSIZE 2 (three units)
    #and an XFERCNT taken from the argument
    Write Register              ${CTRL_REG}  ${LDMA_CTRL}
    #DSTMODE absolute SRCMODE relative DSTINC 1 SIZE BYTE SRCINC 0, with XFERCNT (bits 7:4) supplied by the caller
    Write Register              ${CH${channel}_CTRL_REG}  0x501200${xfercnt}0

Set LDMA_DESCRIPTOR_LINK_M2M_BYTE_SINGLE_JMP
    [Arguments]                 ${first_channel}  ${second_channel}
    Write Register              ${CTRL_REG}  ${LDMA_CTRL}
    Write Register              ${CH${first_channel}_CTRL_REG}  ${CH_CTRL_0_FOR_LINK_TEST}
    Write Register              ${CH${first_channel}_LINK_REG}  ${CH_LINK_0_FOR_LINK_TEST}
    Write Register              ${CH${second_channel}_CTRL_REG}  ${GENERIC_CH_CTRL}
    Write Register              ${CH${second_channel}_LINK_REG}  ${CH_LINK_1_FOR_LINK_TEST}

LDMA Initialization
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    #enable channel 0. CHEN itself is not read back here because it is write only; the enabled
    #channels are reported through CHSTATUS instead
    Write Register                ${CHEN_REG}  0x1
    Register Should Be Equal      ${CHSTATUS_REG}  0x1

Single Transfer SW Request
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    Register Should Be Equal      ${CHDONE_REG}  0x0
    #enable channel 0
    Write Register                ${CHEN_REG}  0x1
    Write Register                ${SWREQ_REG}  0x1
    Write Register                ${IEN_REG}  0x1
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Assert Channel IRQ Is Set     ${CHANNEL0}
    Register Should Be Equal      ${IF_REG}  0x1

Burst SW ALL Transfer Request
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL1}
    #enable channel 0 and channel 1
    Write Register                ${CHEN_REG}  ${BOTH_CHANNELS}
    Write Register                ${SWREQ_REG}  ${BOTH_CHANNELS}
    Write Register                ${IEN_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${CHDONE_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Assert Channel IRQ Is Set     ${CHANNEL0}
    Assert Channel IRQ Is Set     ${CHANNEL1}
    Register Should Be Equal      ${IF_REG}  ${BOTH_CHANNELS}

Burst Block SW Transfer Request
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block  ${CHANNEL0}  ${XFERCNT_1}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block  ${CHANNEL1}  ${XFERCNT_0}
    #enable channel 0 and channel 1
    Write Register                ${CHEN_REG}  ${BOTH_CHANNELS}
    Write Register                ${SWREQ_REG}  ${BOTH_CHANNELS}
    Write Register                ${IEN_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${CHDONE_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Assert Channel IRQ Is Set     ${CHANNEL0}
    Assert Channel IRQ Is Set     ${CHANNEL1}
    Register Should Be Equal      ${IF_REG}  ${BOTH_CHANNELS}

Link Transfer Absolute Request
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    #the structure channel 0 links to, and a byte for it to move
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${LINKED_TRANSFER_CTRL}  ${LINKED_TRANSFER_SOURCE}
    ...                           ${LINKED_TRANSFER_TARGET}  ${NO_LINK}
    Execute Command               sysbus WriteDoubleWord ${LINKED_TRANSFER_SOURCE} ${LINKED_TRANSFER_VALUE}
    Set LDMA_DESCRIPTOR_LINK_M2M_BYTE_SINGLE_JMP  ${CHANNEL0}  ${CHANNEL1}
    #enable channel 0 and channel 1
    Write Register                ${CHEN_REG}  ${BOTH_CHANNELS}
    Write Register                ${SWREQ_REG}  ${BOTH_CHANNELS}
    Write Register                ${IEN_REG}  ${BOTH_CHANNELS}
    #channel 0 completed its own transfer and then the one it linked to
    Memory Should Be Equal        ${LINKED_TRANSFER_TARGET}  ${LINKED_TRANSFER_VALUE}
    Register Should Be Equal      ${CHDONE_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Assert Channel IRQ Is Set     ${CHANNEL0}
    Assert Channel IRQ Is Set     ${CHANNEL1}
    Register Should Be Equal      ${IF_REG}  ${BOTH_CHANNELS}

Relative Link With Negative Displacement
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    #a descriptor at 0x200012DC with LINKMODE relative and a signed displacement of -0x50
    #must fetch the next structure from 0x2000128C; treating LINKADDR as unsigned would
    #wrap to 0x12000128C, which is outside the mapped RAM
    Write Descriptor              0x2000128C  ${WRITE_CTRL_DONEIEN}  ${IMMEDIATE_VALUE}  ${WRITE_TARGET}  ${NO_LINK}
    Write Descriptor              0x200012DC  ${WRITE_CTRL_DONEIEN}  0xA5A5A5A5  0x20001004  0xFFFFFFB3
    Link Load Channel             ${CHANNEL0}  0x200012DC
    #both write structures run: the first, then the one reached by the backward relative link
    Memory Should Be Equal        0x20001004  0xA5A5A5A5
    Memory Should Be Equal        ${WRITE_TARGET}  ${IMMEDIATE_VALUE}
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x1
    Assert Channel IRQ Is Set     ${CHANNEL0}

Transfer Moves Every Unit
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${WORD_TRANSFER_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #the four words are moved in one request, and the words around the destination are untouched
    Transfer Target Word Should Be Equal  -1  0x0
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    Transfer Target Word Should Be Equal  1  ${TRANSFER_WORD_1}
    Transfer Target Word Should Be Equal  2  ${TRANSFER_WORD_2}
    Transfer Target Word Should Be Equal  3  ${TRANSFER_WORD_3}
    Transfer Target Word Should Be Equal  4  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x1

Transfer With Fixed Destination Keeps Last Unit
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${WORD_TRANSFER_FIXED_DST_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #with DSTINC NONE every unit is written to the same address, as for a peripheral register
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_3}
    Transfer Target Word Should Be Equal  1  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${IF_REG}  0x1

Block Transfer Completes Over Multiple Requests
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${WORD_BLOCK_TRANSFER_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #the first request moves one block of two units and leaves the channel armed for the rest
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    Transfer Target Word Should Be Equal  1  ${TRANSFER_WORD_1}
    Transfer Target Word Should Be Equal  2  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x0
    #the second request moves the remaining block from where the first one stopped
    Write Register                ${SWREQ_REG}  0x1
    Transfer Target Word Should Be Equal  2  ${TRANSFER_WORD_2}
    Transfer Target Word Should Be Equal  3  ${TRANSFER_WORD_3}
    Transfer Target Word Should Be Equal  4  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x1

Clearing CHDONE Rearms The Channel
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SINGLE_WORD_TRANSFER_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    Register Should Be Equal      ${CHDONE_REG}  0x1
    #a request on a channel that is still marked done is ignored
    Execute Command               sysbus WriteDoubleWord ${TRANSFER_SOURCE} ${SECOND_TRANSFER_VALUE}
    Write Register                ${SWREQ_REG}  0x1
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    Register Should Be Equal      ${CHDONE_REG}  0x1
    #clearing CHDONE, as the driver does before every start, makes the channel accept it again
    Write Register                ${CHDONE_REG}  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x0
    Write Register                ${SWREQ_REG}  0x1
    Transfer Target Word Should Be Equal  0  ${SECOND_TRANSFER_VALUE}
    Register Should Be Equal      ${CHDONE_REG}  0x1

Request Disable Blocks A Link Load
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SINGLE_WORD_TRANSFER_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    Write Register                ${REQDIS_REG}  0x1
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #the structure is fetched but its request is held off, so nothing is transferred
    Transfer Target Word Should Be Equal  0  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x0
    #clearing REQDIS alone does not replay the request, the next one goes through
    Write Register                ${REQDIS_REG}  0x0
    Transfer Target Word Should Be Equal  0  0x0
    Write Register                ${SWREQ_REG}  0x1
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    Register Should Be Equal      ${CHDONE_REG}  0x1

Interrupt Flag Is Gated By IEN
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Transfer Source Words
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SINGLE_WORD_TRANSFER_CTRL}  ${TRANSFER_SOURCE}  ${TRANSFER_TARGET}  ${NO_LINK}
    #the transfer is requested with the interrupt masked, unlike in the other tests
    Write Register                ${IEN_REG}  0x0
    Write Register                ${CH0_LINK_REG}  ${CH0_DESCRIPTOR_0}
    Write Register                ${LINKLOAD_REG}  0x1
    Transfer Target Word Should Be Equal  0  ${TRANSFER_WORD_0}
    #the flag still latches, but the interrupt line stays low until the channel is unmasked
    Register Should Be Equal      ${IF_REG}  0x1
    Assert Channel IRQ Is Unset    ${CHANNEL0}
    Write Register                ${IEN_REG}  0x1
    Assert Channel IRQ Is Set     ${CHANNEL0}

Write Immediate Structure
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${WRITE_CTRL_DONEIEN}  ${IMMEDIATE_VALUE}  ${WRITE_TARGET}  ${NO_LINK}
    Memory Should Be Equal        ${WRITE_TARGET}  0x0
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #the immediate value is written to the destination address without any transfer request
    Memory Should Be Equal        ${WRITE_TARGET}  ${IMMEDIATE_VALUE}
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x1
    Assert Channel IRQ Is Set     ${CHANNEL0}

Synchronize Structure Sets And Clears Sync Trigger
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SYNC_CTRL_DONEIEN}  ${SET_TRIG_7}  ${NO_MATCH}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #with MATCHEN cleared the structure completes as soon as the pattern is applied
    Register Should Be Equal      ${SYNCSTATUS_REG}  ${SYNC_TRIG_7}
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${IF_REG}  0x1
    #a structure carrying a clear pattern takes the trigger down again
    Write Register                ${CHDONE_REG}  0x0
    Write Descriptor              ${CH0_DESCRIPTOR_1}  ${SYNC_CTRL_DONEIEN}  ${CLEAR_TRIG_7}  ${NO_MATCH}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_1}
    Register Should Be Equal      ${SYNCSTATUS_REG}  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1
    #so does software
    Write Register                ${SYNCSWSET_REG}  ${SYNC_TRIG_7}
    Write Register                ${SYNCSWCLR_REG}  ${SYNC_TRIG_7}
    Register Should Be Equal      ${SYNCSTATUS_REG}  0x0

Synchronize Structure Waits For Cleared Sync Trigger
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    #the awaited condition is SYNCTRIG[7] being clear, so start with it set
    Write Register                ${SYNCSWSET_REG}  ${SYNC_TRIG_7}
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SYNC_CTRL}  ${NO_MATCH}  ${MATCH_TRIG_7_CLEAR}  ${LINK_TO_DESCRIPTOR_1}
    Write Descriptor              ${CH0_DESCRIPTOR_1}  ${WRITE_CTRL_DONEIEN}  ${IMMEDIATE_VALUE}  ${WRITE_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    Memory Should Be Equal        ${WRITE_TARGET}  0x0
    Register Should Be Equal      ${CHBUSY_REG}  0x1
    #clearing the trigger fulfils the match and releases the channel
    Write Register                ${SYNCSWCLR_REG}  ${SYNC_TRIG_7}
    Memory Should Be Equal        ${WRITE_TARGET}  ${IMMEDIATE_VALUE}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1

Synchronize Structure Waits For Software Trigger
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    #a synchronization structure waiting on SYNCTRIG[7], linked to a write immediate structure
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SYNC_CTRL}  ${NO_MATCH}  ${MATCH_TRIG_7_SET}  ${LINK_TO_DESCRIPTOR_1}
    Write Descriptor              ${CH0_DESCRIPTOR_1}  ${WRITE_CTRL_DONEIEN}  ${IMMEDIATE_VALUE}  ${WRITE_TARGET}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    #the channel is parked on the match condition, so the linked structure has not run yet
    Memory Should Be Equal        ${WRITE_TARGET}  0x0
    Register Should Be Equal      ${CHBUSY_REG}  0x1
    Register Should Be Equal      ${CHDONE_REG}  0x0
    #setting the awaited trigger releases the channel
    Write Register                ${SYNCSWSET_REG}  ${SYNC_TRIG_7}
    Memory Should Be Equal        ${WRITE_TARGET}  ${IMMEDIATE_VALUE}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${CHDONE_REG}  0x1
    Register Should Be Equal      ${IF_REG}  0x1

Synchronize Structure Handshake Between Channels
    [Arguments]                 ${ldma_version}
    Create Machine              ${ldma_version}
    #channel 0 waits for SYNCTRIG[7] before running its linked write immediate structure
    Write Descriptor              ${CH0_DESCRIPTOR_0}  ${SYNC_CTRL}  ${NO_MATCH}  ${MATCH_TRIG_7_SET}  ${LINK_TO_DESCRIPTOR_1}
    Write Descriptor              ${CH0_DESCRIPTOR_1}  ${WRITE_CTRL_DONEIEN}  ${IMMEDIATE_VALUE}  ${WRITE_TARGET}  ${NO_LINK}
    #channel 1 sets SYNCTRIG[7]
    Write Descriptor              ${CH1_DESCRIPTOR_0}  ${SYNC_CTRL_DONEIEN}  ${SET_TRIG_7}  ${NO_MATCH}  ${NO_LINK}
    Link Load Channel             ${CHANNEL0}  ${CH0_DESCRIPTOR_0}
    Memory Should Be Equal        ${WRITE_TARGET}  0x0
    Register Should Be Equal      ${CHBUSY_REG}  0x1
    #channel 1 releases channel 0
    Link Load Channel             ${CHANNEL1}  ${CH1_DESCRIPTOR_0}
    Register Should Be Equal      ${SYNCSTATUS_REG}  ${SYNC_TRIG_7}
    Memory Should Be Equal        ${WRITE_TARGET}  ${IMMEDIATE_VALUE}
    Register Should Be Equal      ${CHBUSY_REG}  0x0
    Register Should Be Equal      ${CHDONE_REG}  ${BOTH_CHANNELS}
    Register Should Be Equal      ${IF_REG}  ${BOTH_CHANNELS}


*** Test Cases ***
Should Report Enabled Channel In CHSTATUS
    [Template]                  LDMA Initialization
    0_1
    0_3
    3_3

Should Complete Single Transfer On SW Request
    [Template]                  Single Transfer SW Request
    0_1
    0_3
    3_3

Should Complete Transfers On Both Channels In REQMODE ALL
    [Template]                  Burst SW ALL Transfer Request
    0_1
    0_3
    3_3

Should Complete Block Transfers On Both Channels
    [Template]                  Burst Block SW Transfer Request
    0_1
    0_3
    3_3

Should Run Linked Transfer Structure
    [Template]                  Link Transfer Absolute Request
    0_1
    0_3
    3_3

Should Follow Relative Link With Negative Displacement
    [Template]                  Relative Link With Negative Displacement
    0_1
    0_3
    3_3

Should Move Every Unit Of A Transfer
    [Template]                  Transfer Moves Every Unit
    0_1
    0_3
    3_3

Should Keep Last Unit With Fixed Destination
    [Template]                  Transfer With Fixed Destination Keeps Last Unit
    0_1
    0_3
    3_3

Should Complete Block Transfer Over Multiple Requests
    [Template]                  Block Transfer Completes Over Multiple Requests
    0_1
    0_3
    3_3

Should Rearm Channel When CHDONE Is Cleared
    [Template]                  Clearing CHDONE Rearms The Channel
    0_1
    0_3
    3_3

Should Hold Off Link Load Request While REQDIS Is Set
    [Template]                  Request Disable Blocks A Link Load
    0_1
    0_3
    3_3

Should Gate Interrupt Line With IEN
    [Template]                  Interrupt Flag Is Gated By IEN
    0_1
    0_3
    3_3

Should Execute Write Immediate Structure
    [Template]                  Write Immediate Structure
    0_1
    0_3
    3_3

Should Set And Clear Sync Trigger With Synchronize Structure
    [Template]                  Synchronize Structure Sets And Clears Sync Trigger
    0_1
    0_3
    3_3

Should Wait For Cleared Sync Trigger
    [Template]                  Synchronize Structure Waits For Cleared Sync Trigger
    0_1
    0_3
    3_3

Should Wait For Software Sync Trigger
    [Template]                  Synchronize Structure Waits For Software Trigger
    0_1
    0_3
    3_3

Should Hand Off Between Channels With Sync Trigger
    [Template]                  Synchronize Structure Handshake Between Channels
    0_1
    0_3
    3_3
