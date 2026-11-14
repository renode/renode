*** Variables ***
${FREQUENCY}                        39000000

# Registers
${CFG1_REG}                         0x000C
${CMD_REG}                          0x0038
${RXDATA_REG}                       0x003C
${RXDATAP_REG}                      0x0040
${TXDATA_REG}                       0x0044
${STATUS_REG}                       0x0048
${IF_REG}                           0x004C
${IEN_REG}                          0x0050

${IF_CLR_REG}                       0x204C
${IEN_CLR_REG}                      0x2050

# CMD register commands
${CMD_NONE}                         0x0
${CMD_RXEN}                         0x1
${CMD_TXEN}                         0x4
${CMD_RXEN_TXEN}                    0x5

# Bit fields for EUSART STATUS
${EUSART_STATUS_RXENS}              0x1                     #< Receiver Enable Status
${EUSART_STATUS_TXENS}              0x2                     #< Transmitter Enable Status

# Bit fields for EUSART IF
${_EUSART_IF_MASK}                  0x030D3FFF              #< Mask for EUSART_IF
${_EUSART_IF_CSWU_MASK}             0x00010000              #< Bit mask for EUSART_CSWU
${EUSART_IF_TXC}                    0x1                     #< TX Complete Interrupt Flag
${EUSART_IF_RXFL}                   0x4                     #< RX FIFO Level Interrupt Flag
${EUSART_IF_STARTF}                 0x40000                 #< Start Frame Interrupt Flag

# test specific vars
${NUM_SAMPLES}                      0x4
${EXPECTED_START_STATUS_TX}         0x3042
${EXPECTED_END_STATUS_TX}           0x3062
${EXPECTED_START_IF_TX}             0x2
${EXPECTED_END_IF_TX}               0x3
${EXPECTED_START_STATUS_RX}         0x3041
${EXPECTED_START_IF_RX}             0x0
${EXPECTED_END_IF_RX}               0x4

${CFG1_RXWATERMARK_2}               0x08000000
${CFG1_RXWATERMARK_3}               0x10000000
${EXPECTED_START_STATUS_RX_MULTI}   0x3041
${EXPECTED_END_STATUS_RX_MULTI}     0x30C1

*** Keywords ***
Create Machine
    [Arguments]                     ${ip_version}
    Reset Emulation
    Execute Command                 mach create "test"
    ${repl}=  Catenate              SEPARATOR=\n
    ...  """
    ...  eusart: UART.SiLabs_EUSART_${ip_version} @ sysbus <0x0, +0x4000>
    ...  cmu: Miscellaneous.SiLabs.SiLabs_CMU_1 @ sysbus <0x04000, +0x4000>
    ...  ${SPACE*4}hfxoFrequency: ${FREQUENCY}
    ...  """
    Execute Command                 machine LoadPlatformDescriptionFromString ${repl}

Write Register
    [Arguments]                     ${register}  ${value}
    Execute Command                 sysbus.eusart WriteDoubleWord ${register} ${value}

Register Should Be Equal
    [Arguments]                     ${register}  ${expected}
    ${value}=  Execute Command      sysbus.eusart ReadDoubleWord ${register}
    Should Be Equal As Integers     ${value}  ${expected}

RX FIFO Level Flag Should Be ${state:(Set|Clear)}
    IF  '${state}' == 'Set'
        Register Should Be Equal    ${IF_REG}  ${EXPECTED_END_IF_RX}
        Register Should Be Equal    ${STATUS_REG}  ${EXPECTED_END_STATUS_RX_MULTI}
    ELSE
        Register Should Be Equal    ${IF_REG}  ${EXPECTED_START_IF_RX}
        Register Should Be Equal    ${STATUS_REG}  ${EXPECTED_START_STATUS_RX_MULTI}
    END

Command Should Set Enable Status
    [Arguments]                     ${ip_version}  ${command}  ${rxens}  ${txens}
    Create Machine                  ${ip_version}
    Write Register                  ${CMD_REG}  ${command}
    ${status}=  Execute Command     sysbus.eusart ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers     ${{int($status, 16) & ${EUSART_STATUS_RXENS}}}  ${rxens}  #check RXENS
    Should Be Equal As Integers     ${{int($status, 16) & ${EUSART_STATUS_TXENS}}}  ${txens}  #check TXENS

Interrupt Registers Should Set And Clear
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    Write Register                  ${CMD_REG}  ${CMD_RXEN_TXEN}
    #TXFL goes high as soon as there is space in the Tx FIFO,
    #so IF reads 0x2 once the transmitter is enabled.
    Register Should Be Equal        ${IF_REG}  0x2

    #check setting interrupt flags
    ${flag}=  Set Variable          ${{hex(${_EUSART_IF_MASK} & ~${_EUSART_IF_CSWU_MASK})}}  #EM2 mode
    Write Register                  ${IF_REG}  ${flag}
    Register Should Be Equal        ${IF_REG}  ${flag}

    #check intEnable
    ${flag}=  Set Variable          ${{hex(${EUSART_IF_RXFL} | ${EUSART_IF_STARTF} | ${EUSART_IF_TXC})}}
    Write Register                  ${IEN_REG}  ${flag}
    Register Should Be Equal        ${IEN_REG}  ${flag}

    #check intDisable
    Write Register                  ${IEN_CLR_REG}  ${flag}
    Register Should Be Equal        ${IEN_REG}  0x0

    #checkIntClear
    ${if_before_clear}=  Execute Command  sysbus.eusart ReadDoubleWord ${IF_REG}
    ${flag}=  Set Variable          ${{hex(${_EUSART_IF_MASK} & ~(${flag} | 3))}}
    Write Register                  ${IF_CLR_REG}  ${flag}
    Register Should Be Equal        ${IF_REG}  ${{int($if_before_clear, 16) & ~${flag}}}

Asynchronous TX Should Transmit Frames
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    #select ${NUM_SAMPLES} distinct random numbers between 1 and 10 inclusive
    ${data_list}=  Set Variable     ${{random.sample(range(1, 11), ${NUM_SAMPLES})}}

    Write Register                  ${CMD_REG}  ${CMD_TXEN}
    Register Should Be Equal        ${STATUS_REG}  ${EXPECTED_START_STATUS_TX}

    FOR  ${data}  IN  @{data_list}
        Register Should Be Equal    ${IF_REG}  ${EXPECTED_START_IF_TX}
        Write Register              ${TXDATA_REG}  ${data}
        Register Should Be Equal    ${IF_REG}  ${EXPECTED_END_IF_TX}
        Register Should Be Equal    ${STATUS_REG}  ${EXPECTED_END_STATUS_TX}
        #clear the TX complete flag before the next frame, as software would, leaving only TXFL set
        Write Register              ${IF_REG}  0x2
    END

Asynchronous RX Should Receive Frames
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    #select ${NUM_SAMPLES} distinct random characters between a and k
    ${data_list}=  Set Variable     ${{random.sample(range(97, 108), ${NUM_SAMPLES})}}

    Write Register                  ${CMD_REG}  ${CMD_RXEN}

    FOR  ${data}  IN  @{data_list}
        Register Should Be Equal    ${STATUS_REG}  ${EXPECTED_START_STATUS_RX}
        Register Should Be Equal    ${IF_REG}  ${EXPECTED_START_IF_RX}
        Execute Command             sysbus.eusart WriteChar ${data}
        Register Should Be Equal    ${RXDATA_REG}  ${data}
    END

RXDATAP Should Not Pop The FIFO
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    #select a random number between chars a-k in ascii
    ${data}=  Set Variable          ${{random.randint(97, 107)}}

    Write Register                  ${CMD_REG}  ${CMD_RXEN}

    # Write data into receive pipeline fifos
    Execute Command                 sysbus.eusart WriteChar ${data}

    # Read fifo slot twice to ensure RXDATAP does not pop from the fifo
    Register Should Be Equal        ${RXDATAP_REG}  ${data}
    Register Should Be Equal        ${RXDATAP_REG}  ${data}

Asynchronous RX Should Honour The FIFO Watermark
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    #select ${NUM_SAMPLES} distinct random characters between a and k
    ${data_list}=  Set Variable     ${{random.sample(range(97, 108), ${NUM_SAMPLES})}}

    Write Register                  ${CMD_REG}  ${CMD_RXEN}

    # Assert rxflif is zero to start
    RX FIFO Level Flag Should Be Clear

    # Write data into receive pipeline fifos
    Execute Command                 sysbus.eusart WriteChar ${data_list}[0]

    # Check RXFLIF is set as watermark is set to 1 currently
    RX FIFO Level Flag Should Be Set

    # Reset interrupt flag by emptying fifo by popping the single data element inserted
    Execute Command                 sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    RX FIFO Level Flag Should Be Clear

    # Reconfigure fifo watermark to 2
    Write Register                  ${CFG1_REG}  ${CFG1_RXWATERMARK_2}

    # Write single data element into fifo and ensure RXFLIF is not set
    Execute Command                 sysbus.eusart WriteChar ${data_list}[0]
    RX FIFO Level Flag Should Be Clear

    # Write second data element into fifo and ensure RXFLIF is set
    Execute Command                 sysbus.eusart WriteChar ${data_list}[1]
    RX FIFO Level Flag Should Be Set

    # Reset interrupt flag by emptying fifo by popping both data elements inserted
    Execute Command                 sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    Execute Command                 sysbus.eusart ReadDoubleWord ${RXDATA_REG}
    RX FIFO Level Flag Should Be Clear

    # Reconfigure fifo watermark to 3
    Write Register                  ${CFG1_REG}  ${CFG1_RXWATERMARK_3}

    # Write single data element into fifo and ensure RXFLIF is not set
    Execute Command                 sysbus.eusart WriteChar ${data_list}[0]
    RX FIFO Level Flag Should Be Clear

    # Write second data element into fifo and ensure RXFLIF is not set
    Execute Command                 sysbus.eusart WriteChar ${data_list}[1]
    RX FIFO Level Flag Should Be Clear

    # Write third data element into fifo and ensure RXFLIF is set
    Execute Command                 sysbus.eusart WriteChar ${data_list}[2]
    RX FIFO Level Flag Should Be Set

    # Read out all data elements from fifo and ensure they are correct values
    Register Should Be Equal        ${RXDATA_REG}  ${data_list}[0]
    Register Should Be Equal        ${RXDATA_REG}  ${data_list}[1]
    Register Should Be Equal        ${RXDATA_REG}  ${data_list}[2]

*** Test Cases ***
Should Report RX And TX Enable Status
    [Template]                      Command Should Set Enable Status
    # IP version  command           RXENS                   TXENS
    2             ${CMD_RXEN}       ${EUSART_STATUS_RXENS}  0
    4             ${CMD_RXEN}       ${EUSART_STATUS_RXENS}  0
    2             ${CMD_TXEN}       0                       ${EUSART_STATUS_TXENS}
    4             ${CMD_TXEN}       0                       ${EUSART_STATUS_TXENS}
    2             ${CMD_RXEN_TXEN}  ${EUSART_STATUS_RXENS}  ${EUSART_STATUS_TXENS}
    4             ${CMD_RXEN_TXEN}  ${EUSART_STATUS_RXENS}  ${EUSART_STATUS_TXENS}
    2             ${CMD_NONE}       0                       0
    4             ${CMD_NONE}       0                       0

Should Set And Clear Interrupt Registers
    [Template]                      Interrupt Registers Should Set And Clear
    2
    4

Should Transmit Asynchronous Frames
    [Template]                      Asynchronous TX Should Transmit Frames
    2
    4

Should Receive Asynchronous Frames
    [Template]                      Asynchronous RX Should Receive Frames
    2
    4

Should Peek RX Data Without Popping
    [Template]                      RXDATAP Should Not Pop The FIFO
    2
    4

Should Raise RX FIFO Level Flag At Watermark
    [Template]                      Asynchronous RX Should Honour The FIFO Watermark
    2
    4
