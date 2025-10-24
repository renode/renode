*** Variables ***
${FREQUENCY}                    39000000
# The IP_VERSION variable must be set from command line
# For example: renode-test --variable IP_VERSION: <EUSART VERSION to being tested> this_test.robot
${IP_VERSION}                   2
${REPL_STRING}=                 SEPARATOR=
...  """                                                                    ${\n}
...  eusart: UART.SiLabs_EUSART_${IP_VERSION} @ sysbus <0x0, +0x4000>       ${\n}
...  ${SPACE*4}clockFrequency: ${FREQUENCY}                                 ${\n}
...  """

# Registers
${EN_REG}                     0x0004
${CFG0_REG}                   0x0008
${CFG1_REG}                   0x000C
${CFG2_REG}                   0x0010
${FRAMECFG_REG}               0x0014
${DTXDATACFG_REG}             0x0018
${IRHFCFG_REG}                0x001C
${IRLFCFG_REG}                0x0020
${TIMINGCFG_REG}              0x0024
${STARTFRAMECFG_REG}          0x0028
${SIGFRAMECFG_REG}            0x002C
${CLKDIV_REG}                 0x0030
${TRIGCTRL_REG}               0x0034
${CMD_REG}                    0x0038
${RXDATA_REG}                 0x003C
${RXDATAP_REG}                0x0040
${TXDATA_REG}                 0x0044
${STATUS_REG}                 0x0048
${IF_REG}                     0x004C
${IEN_REG}                    0x0050
${SYNCBUSY_REG}               0x0054
${DALICFG_REG}                0x0058
${TEST_REG}                   0x0100

${IF_CLR_REG}                 0x204C
${IEN_CLR_REG}                0x2050
${STATUS_CLR_REG}             0x2048


# Bit fields for EUSART STATUS 
${_EUSART_STATUS_RESETVALUE}          0x00003040UL                 #< Default value for EUSART_STATUS
${_EUSART_STATUS_MASK}                0x031F31FBUL                 #< Mask for EUSART_STATUS
${EUSART_STATUS_RXENS}                0x1                          #< Receiver Enable Status
${_EUSART_STATUS_RXENS_SHIFT}         0                            #< Shift value for EUSART_RXENS
${_EUSART_STATUS_RXENS_MASK}          0x1                          #< Bit mask for EUSART_RXENS
${_EUSART_STATUS_RXENS_DEFAULT}       0x00000000                   #< Mode DEFAULT for EUSART_STATUS
${EUSART_STATUS_RXENS_DEFAULT}        0x00000000                   #< Shifted mode DEFAULT for EUSART_STATUS
${EUSART_STATUS_TXENS}                0x2                          #< Transmitter Enable Status
${_EUSART_STATUS_TXENS_SHIFT}         1                            #< Shift value for EUSART_TXENS
${_EUSART_STATUS_TXENS_MASK}          0x2                          #< Bit mask for EUSART_TXENS
${_EUSART_STATUS_TXENS_DEFAULT}       0x00000000                   #< Mode DEFAULT for EUSART_STATUS

# Bit fields for EUSART IF 
${_EUSART_IF_MASK}                    0x030D3FFF                   #< Mask for EUSART_IF
${_EUSART_IF_CSWU_MASK}               0x00010000                   #< Bit mask for EUSART_CSWU
${EUSART_IF_TXC}                      0x1                          #< TX Complete Interrupt Flag                 
${EUSART_IF_RXFL}                     0x3                          #< RX FIFO Level Interrupt Flag                
${EUSART_IF_STARTF}                   0x1000000                    #< Start Frame Interrupt Flag

# Bit fields for EUSART SYNCBUSY 
${_EUSART_SYNCBUSY_RESETVALUE}        0x00000000                   #< Default value for EUSART_SYNCBUSY           
${_EUSART_SYNCBUSY_MASK}              0x00000FFF                   #< Mask for EUSART_SYNCBUSY                    
${EUSART_SYNCBUSY_DIV}                0x1                          #< SYNCBUSY for DIV in CLKDIV                  
${_EUSART_SYNCBUSY_DIV_SHIFT}         0                            #< Shift value for EUSART_DIV                  
${_EUSART_SYNCBUSY_DIV_MASK}          0x1                          #< Bit mask for EUSART_DIV                     
${_EUSART_SYNCBUSY_DIV_DEFAULT}       0x00000000                   #< Mode DEFAULT for EUSART_SYNCBUS

# test specific vars
${NUM_SAMPLES}                        0x4
${EXPECTED_START_STATUS_TX}           0x3042  
${EXPECTED_END_STATUS_TX}             0x3062  
${EXPECTED_START_IF_TX}               0x2  
${EXPECTED_END_IF_TX}                 0x3  
${EXPECTED_START_STATUS_RX}           0x3041
${EXPECTED_START_IF_RX}               0x0
${EXPECTED_END_IF_RX}                 0x4

${CFG1_RXWATERMARK_2}                 0x08000000
${CFG1_RXWATERMARK_3}                 0x10000000
${EXPECTED_START_STATUS_RX_MULTI}     0x3041  
${EXPECTED_END_STATUS_RX_MULTI}       0x30C1  

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}

Enable Rx Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x1

Disable Rx Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x2

Enable Tx Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x4

Enable Rx Tx Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x5

Disable Tx Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x8

Disable RXBLOCK Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x10

All Off Command
    Execute Command             sysbus.eusart WriteDoubleWord ${CMD_REG} 0x0

Assert Receive IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.eusart ReceiveIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert Receive IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.eusart ReceiveIRQ
    Should Contain                  ${irqState}  GPIO: unset

Assert Transmit IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.eusart TransmitIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert Transmit IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.eusart TransmitIRQ
    Should Contain                  ${irqState}  GPIO: unset
   
*** Test Cases ***
EUSART IP Selection
    Log to Console                SiLabs_EUSART_${IP_VERSION} TESTSUITE
    Log to Console                ${REPL_STRING}
    
Enable Rx Only
    Create Machine
    Enable Rx Command    
    ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register RXEN only 
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_RXENS_MASK}",16)) #check RXENS 
    ${check_val}                evaluate  hex(${EUSART_STATUS_RXENS})               
    Should Be Equal As Integers   ${read_val}  ${check_val}    
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_TXENS_MASK}",16)) #check TXENS
    ${check_val}                evaluate  0x0                
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Disable Rx Command

Enable Tx Only
    Create Machine
    Enable Tx Command
    ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_RXENS_MASK}",16)) #check RXENS 
    ${check_val}                evaluate  0x0               
    Should Be Equal As Integers   ${read_val}  ${check_val}      
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_TXENS_MASK}",16)) #check TXENS 
    ${check_val}                evaluate  hex(${EUSART_STATUS_TXENS})                 
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Disable Tx Command

Enable Rx Tx
    Create Machine
    Enable Rx Tx Command
    ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_RXENS_MASK}",16)) #check RXENS 
    ${check_val}                evaluate  hex(${EUSART_STATUS_RXENS})               
    Should Be Equal As Integers   ${read_val}  ${check_val}      
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_TXENS_MASK}",16)) #check TXENS 
    ${check_val}                evaluate  hex(${EUSART_STATUS_TXENS})                 
    Should Be Equal As Integers   ${read_val}  ${check_val}    
    All Off Command

Enables Disabled
    Create Machine
    All Off Command
    ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_RXENS_MASK}",16)) #check RXENS 
    ${check_val}                evaluate  0x0               
    Should Be Equal As Integers   ${read_val}  ${check_val}      
    ${read_val}                 evaluate  hex(${statusState} & int("${_EUSART_STATUS_TXENS_MASK}",16)) #check TXENS 
    ${check_val}                evaluate  0x0                 
    Should Be Equal As Integers   ${read_val}  ${check_val}  

Interrupts 
    Create Machine
    Enable Rx Tx Command
    ${check_val}                  evaluate  hex(2) #TXFL goes high as soon as there is space in the Tx FIFO.
    ${read_val}=                  Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    #Test reset value;
    Should Be Equal As Integers   ${read_val}  ${check_val} 
   
    #set sync busy reg
    Execute Command               sysbus.eusart WriteDoubleWord ${SYNCBUSY_REG} ${_EUSART_SYNCBUSY_MASK }
    #check setting interrupt flags
    ${flag}                       evaluate  hex(int("${_EUSART_IF_MASK}",16) & ~int("${_EUSART_IF_CSWU_MASK}",16))  #EM2 mode
    # ${flag}                     evaluate  hex(int("${_EUSART_IF_MASK}",16))
    ${check_val}                  evaluate  hex(63)  #cfg for other modes not set so upper bits are usually not set 
    Execute Command               sysbus.eusart WriteDoubleWord ${IF_REG} ${flag}
    ${read_val}=                  Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  ${check_val}

    #check intEnable 
    ${flag}                       evaluate  hex( int("${EUSART_IF_RXFL}",16) | int("${EUSART_IF_STARTF}",16) | int("${EUSART_IF_TXC}",16) )
    Execute Command               sysbus.eusart WriteDoubleWord ${IEN_REG} ${flag}
    ${read_val}=                  Execute Command  sysbus.eusart ReadDoubleWord ${IEN_REG}
    ${check_val}                  evaluate  hex(3)  #cfg for other modes not set so upper bits are usually not set 
    Should Be Equal As Integers   ${read_val}  ${check_val}

    #check intDisable
    ${check_val}                  evaluate  hex(0)
    Execute Command               sysbus.eusart WriteDoubleWord ${IEN_CLR_REG} ${flag}
    ${read_val}=                  Execute Command  sysbus.eusart ReadDoubleWord ${IEN_REG}
    Should Be Equal As Integers   ${read_val}  ${check_val}

    #checkIntClear
    ${check_val}                  evaluate  hex(3) 
    ${flag}                       evaluate  hex(${${_EUSART_IF_MASK} } & ~(${flag} | 3))
    Execute Command               sysbus.eusart WriteDoubleWord ${IF_CLR_REG} ${flag}
    ${read_val}=                  Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  ${check_val}

    #clear sync busy reg
    Execute Command               sysbus.eusart WriteDoubleWord ${SYNCBUSY_REG} 0x00000000
    Disable RXBLOCK Command

Asynchronous TX 
    Create Machine
    ${data_list}=                       evaluate  random.sample(range(1, 11), ${NUM_SAMPLES})  #select a random number between 1 and 10 inclusive
    
    Enable Tx Command
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only 
    ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
    Should Be Equal As Integers  ${statusState}  ${EXPECTED_START_STATUS_TX}

    FOR  ${data}  IN  @{data_list}
        ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
        ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only 
        Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_TX}
        Execute Command               sysbus.eusart WriteDoubleWord ${TXDATA_REG} ${data}
        ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
        ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only
        Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_END_IF_TX}
        Should Be Equal As Integers  ${statusState}  ${expected_end_status_tx}        
        #clear tx complete Interupt flag when new frame is available
        Execute Command  sysbus.eusart WriteDoubleWord ${IF_REG} 0x2
        #clear tx complete status (software would do)
    END 
    Disable Tx Command

Asynchronous RX
    Create Machine
    ${data_list}=                       evaluate  random.sample(range(97, 108), ${NUM_SAMPLES})  #select a random number between chars a-k in ascii
    
    Enable Rx Command

    FOR  ${data}  IN  @{data_list}
        ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only 
        ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 

        ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only 
        ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
        Should Be Equal As Integers  ${statusState}  ${_expected_start_status_rx}
        Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}

        Execute Command  sysbus.eusart WriteChar ${data}

        ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG} 
        Should Be Equal As Integers  ${rxData}  ${data}
        ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG} #Read STATUS register TXEN only 
        ${statusState}=             Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG} #Read STATUS register TXEN only 
    END
    
    Disable Rx Command

RX DATA PEAK
    Create Machine
    ${data_list}=                       evaluate  random.sample(range(97, 108), ${NUM_SAMPLES})  #select a random number between chars a-k in ascii
    
    Enable Rx Command

    # Write data into receive pipeline fifos
    Execute Command  sysbus.eusart WriteChar ${data_list}[0]

    # Read fifo slot twice to ensure RXDATAP does not pop from the fifo
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATAP_REG} 
    Should Be Equal As Integers  ${rxData}  ${data_list}[0]
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATAP_REG} 
    Should Be Equal As Integers  ${rxData}  ${data_list}[0]
    Disable Rx Command

Asynchronous RX Multiframe
    Create Machine
    ${data_list}=                       evaluate  random.sample(range(97, 108), ${NUM_SAMPLES})  #select a random number between chars a-k in ascii

    Enable Rx Command
    
    # Assert rxflif is zero to start
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 

    # Write data into receive pipeline fifos
    Execute Command  sysbus.eusart WriteChar ${data_list}[0]

    # Check RXFLIF is set as watermark is set to 1 currently
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_END_IF_RX} 
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_END_STATUS_RX_MULTI} 

    # Reset interupt flag by emptying fifo by popping the single data element inserted
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG} 
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 

    # Reconfigure fifo watermark to 2
    Execute Command  sysbus.eusart WriteDoubleWord ${CFG1_REG} ${CFG1_RXWATERMARK_2}

    # Write single data element into fifo and ensure RXFLIF is not set
    Execute Command  sysbus.eusart WriteChar ${data_list}[0]
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}

    # Write second data element into fifo and ensure RXFLIF is set
    Execute Command  sysbus.eusart WriteChar ${data_list}[1]
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_END_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_END_STATUS_RX_MULTI} 

    # Reset interupt flag by emptying fifo by popping the both data elements inserted
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG} 
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG} 
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 

    # Reconfigure fifo watermark to 3
    Execute Command  sysbus.eusart WriteDoubleWord ${CFG1_REG} ${CFG1_RXWATERMARK_3} 

    # Write single data element into fifo and ensure RXFLIF is not set
    Execute Command  sysbus.eusart WriteChar ${data_list}[0]
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 

    # Write second data element into fifo and ensure RXFLIF is not set
    Execute Command  sysbus.eusart WriteChar ${data_list}[1]
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_START_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_START_STATUS_RX_MULTI} 

    # Write third data element into fifo and ensure RXFLIF is set
    Execute Command  sysbus.eusart WriteChar ${data_list}[2]
    ${StatusState}=       Execute Command  sysbus.eusart ReadDoubleWord ${STATUS_REG}
    ${InteruptFlagState}=       Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers  ${InteruptFlagState}  ${EXPECTED_END_IF_RX}
    Should Be Equal As Integers  ${StatusState}  ${EXPECTED_END_STATUS_RX_MULTI} 

    # Read out all data elements from fifo and ensure they are correct values
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    Should Be Equal As Integers  ${rxData}  ${data_list}[0]
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    Should Be Equal As Integers  ${rxData}  ${data_list}[1]
    ${rxData}=             Execute Command  sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    Should Be Equal As Integers  ${rxData}  ${data_list}[2]

    Disable Rx Command

