*** Variables ***
${REPL_STRING}=                 SEPARATOR=
...  """                                                                                                        
...  ldma: DMA.SiLabs_LDMA_3_3 @ {                                                                               ${\n}
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40814000; size: 0x4000; region: "ldma_ns" };     ${\n}
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x50814000; size: 0x4000; region: "ldma_s" };      ${\n}
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x40844000; size: 0x4000; region: "ldmaxbar_ns" }; ${\n}
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x50844000; size: 0x4000; region: "ldmaxbar_s" }   ${\n}
...  ${SPACE*8}}                                                                                                 ${\n}
...  """

# Registers
${EN_REG}                    0x0004
${SWRST_REG}                 0x0008
${CTRL_REG}                  0x000C
${STATUS_REG}                0x0010
${SYNCSWSET_REG}             0x0014
${SYNCSWCLR_REG}             0x0018
${SYNCHWEN_REG}              0x001C
${SYNCHWSEL_REG}             0x0020
${SYNCSTATUS_REG}            0x0024
${CHEN_REG}                  0x0028
${CHDIS_REG}                 0x002C
${CHSTATUS_REG}              0x0030
${CHBUSY_REG}                0x0034
${CHDONE_REG}                0x0038
${DBGHALT_REG}               0x003C
${SWREQ_REG}                 0x0040
${REQDIS_REG}                0x0044
${REQPEND_REG}               0x0048
${LINKLOAD_REG}              0x004C
${REQCLEAR_REG}              0x0050
${IF_REG}                    0x0054
${IEN_REG}                   0x0058
${REQABORT_REG}              0x005C
${ABORTSTATUS_REG}           0x0060
${CH0_CTRL_REG}              0x0078
${CH1_CTRL_REG}              0x00A8
${CH0_LINK_REG}              0x0084
${CH1_LINK_REG}              0x00B4
#ldma test vars
${LDMA_CTRL}                 0x1000000
${EXPECTED_START_CHDONE}     0x0
${EXPECTED_END_CHDONE}       0x1
${EXPECTED_END_CHDONE_ALL}   0x3
${CHANNEL0}                  0 
${CHANNEL1}                  1 
${BLOCKSIZE_0}               0
${BLOCKSIZE_1}               1
${GENERIC_CH_CTRL}           0x50310000  
${CH_CTRL_0_FOR_LINK_TEST}   0xD0310000
${CH_LINK_0_FOR_LINK_TEST}   0x12
${CH_LINK_1_FOR_LINK_TEST}   0x51

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}

Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE
    [Arguments]                 ${channel}
    #sets fixed priority to 1 and enables done set as well as req mode all
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CTRL_REG} 0x2000000
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${channel}_CTRL_REG} ${GENERIC_CH_CTRL} 

Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block
    [Arguments]                 ${channel}  ${blockSize}
    #sets fixed priority to 1 and enables done set as well as req mode block and block size 2 and transfer count will be 4
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CTRL_REG} 0x2000000
    #Sets channel descriptor DSTMODE absolute SRCMODE relative DSTINC 1 SIZE BYTE SRCINC 0  with configurable blocksize as an input argument
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${channel}_CTRL_REG} 0x501200${blockSize}0

Set LDMA_DESCRIPTOR_LINKREL_M2M_BYTE_SINGLE_JMP
    [Arguments]                 ${first_channel}  ${second_channel}
    #sets fixed priority to 1 and enables done set as well as req mode block and block size 2 and transfer count will be 4
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CTRL_REG} 0x2000000   
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${first_channel}_CTRL_REG} ${CH_CTRL_0_FOR_LINK_TEST}
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${first_channel}_LINK_REG} ${CH_LINK_0_FOR_LINK_TEST}
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${second_channel}_CTRL_REG} ${GENERIC_CH_CTRL} 
    Execute Command             sysbus.ldma WriteDoubleWordToLdma ${CH${second_channel}_LINK_REG} ${CH_LINK_1_FOR_LINK_TEST}

*** Test Cases ***
LDMA Initialization
    Create Machine
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CTRL_REG}
    #enable channel 0
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${CHEN_REG} 0x1
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHEN_REG}
    Should Be Equal As Integers   ${read_val}  1
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHSTATUS_REG}
    Should Be Equal As Integers   ${read_val}  1

Single Transfer SW Request
    Create Machine
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    #enable channel 0
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHDONE_REG}
    Should Be Equal As Integers   ${read_val}  ${EXPECTED_START_CHDONE}
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${CHEN_REG} 0x1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${SWREQ_REG} 0x1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${IEN_REG} 0x1
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHDONE_REG}
    Should Be Equal As Integers   ${read_val}  ${EXPECTED_END_CHDONE}
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${irqState}=                  Execute Command  sysbus.ldma Channel0IRQ
    Should Contain                ${irqState}  GPIO: set
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${IF_REG}
    Should Be Equal As Integers   ${read_val}  1

Burst SW ALL Transfer Request
    Create Machine
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL0}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE  ${CHANNEL1}
    #enable channel 0 and channel 1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${CHEN_REG} 0x3
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${SWREQ_REG} 0x1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${IEN_REG} 0x3
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHDONE_REG}
    Should Be Equal As Integers   ${read_val}  ${EXPECTED_END_CHDONE_ALL}
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${irqState}=                  Execute Command  sysbus.ldma Channel0IRQ
    Should Contain                ${irqState}  GPIO: set
    ${irqState}=                  Execute Command  sysbus.ldma Channel1IRQ
    Should Contain                ${irqState}  GPIO: set
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${IF_REG}
    Should Be Equal As Integers   ${read_val}  3

Burst Block SW Transfer Request
    #Block transer
    Create Machine
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block  ${CHANNEL0}  ${BLOCKSIZE_1}
    Set LDMA_DESCRIPTOR_SINGLE_M2M_BYTE Block  ${CHANNEL1}  ${BLOCKSIZE_0}
    #enable channel 0 and channel 1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${CHEN_REG} 0x3
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${SWREQ_REG} 0x1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${IEN_REG} 0x3
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHDONE_REG}
    Should Be Equal As Integers   ${read_val}  ${EXPECTED_END_CHDONE_ALL}
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${irqState}=                  Execute Command  sysbus.ldma Channel0IRQ
    Should Contain                ${irqState}  GPIO: set
    ${irqState}=                  Execute Command  sysbus.ldma Channel1IRQ
    Should Contain                ${irqState}  GPIO: set
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${IF_REG}
    Should Be Equal As Integers   ${read_val}  3

Link Transfer Relative Request
    Create Machine
    Set LDMA_DESCRIPTOR_LINKREL_M2M_BYTE_SINGLE_JMP  ${CHANNEL0}  ${CHANNEL1}
    #enable channel 0 and channel 1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${CHEN_REG} 0x3
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${SWREQ_REG} 0x1
    Execute Command               sysbus.ldma WriteDoubleWordToLdma ${IEN_REG} 0x3
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHDONE_REG}
    Should Be Equal As Integers   ${read_val}  ${EXPECTED_END_CHDONE_ALL}
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${CHBUSY_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${irqState}=                  Execute Command  sysbus.ldma Channel0IRQ
    Should Contain                ${irqState}  GPIO: set
    ${irqState}=                  Execute Command  sysbus.ldma Channel1IRQ
    Should Contain                ${irqState}  GPIO: set
    ${read_val}=                  Execute Command  sysbus.ldma ReadDoubleWordFromLdma ${IF_REG}
    Should Be Equal As Integers   ${read_val}  3
