*** Keywords ***
Command Result Should Be Number
    [Arguments]  ${command}  ${result}

    ${actual}=  Execute Command        ${command}
    Should Be Equal As Numbers         ${actual}  ${result}

Create Bus Isolation Machine
    ${SCRIPT_PATH}=                    Evaluate  r"${CURDIR}/bus_isolation.resc".replace(" ", "\\ ")
    Execute Script                     ${SCRIPT_PATH}


*** Test Cases ***
Should Handle Separation By State In Secure World
    Create Bus Isolation Machine
    Execute Command                    cpu0 Step 100

    Register Should Be Equal           3  0x1010
    Register Should Be Equal           4  0x2020
    Register Should Be Equal           5  0x3030
    Register Should Be Equal           6  0x4444
    Register Should Be Equal           7  0x63707507
    Register Should Be Equal           8  0x63707507
    Register Should Be Equal           9  0x1010
    Register Should Be Equal           10  0
    Register Should Be Equal           11  0x3030
    Register Should Be Equal           12  0x0404
    Register Should Be Equal           13  0x63707506
    Register Should Be Equal           14  0x63707506


Should Handle Separation By State In Nonsecure World
    Create Bus Isolation Machine
    Execute Command                    cpu0 SecureState false
    Execute Command                    cpu0 Step 100

    Register Should Be Equal           3  0
    Register Should Be Equal           4  0
    Register Should Be Equal           5  0x3030
    Register Should Be Equal           6  0x4444
    Register Should Be Equal           7  0x63707501
    Register Should Be Equal           8  0x63707501
    Register Should Be Equal           9  0x1010
    Register Should Be Equal           10  0
    Register Should Be Equal           11  0x3030
    Register Should Be Equal           12  0x0404
    Register Should Be Equal           13  0x63707500
    Register Should Be Equal           14  0x63707500

Should Read Through Privilege Aware Reader
    Create Bus Isolation Machine

    #                                                      ↓ raw initiator state which gets passed to the peripheral
    Command Result Should Be Number    reader Read 0x10010 0x00  0x72656100
    Command Result Should Be Number    reader Read 0x10010 0x01  0x72656101
    Command Result Should Be Number    reader Read 0x10010 0xa5  0x726561a5

    # Now we'll read some peripherals that have various conditions.
    Command Result Should Be Number    reader Read 0x10008 0x00  0x3030  # no condition
    Command Result Should Be Number    reader Read 0x10008 0x01  0x3030  # no condition

    # condition: privileged and condition: !privileged, here decoded according to CortexM.StateBits,
    # so it should only differ based on bit[0] of state
    Command Result Should Be Number    reader Read 0x1000c 0x00  0x0404
    Command Result Should Be Number    reader Read 0x1000c 0x01  0x4444
    Command Result Should Be Number    reader Read 0x1000c 0x02  0x0404
    Command Result Should Be Number    reader Read 0x1000c 0x03  0x4444

    # condition: cpuSecure && privileged && initiator == cpu0, so we will not be able to read it even if the correct state
    # (0x3) is specified
    Command Result Should Be Number    reader Read 0x10004 0x00  0
    Command Result Should Be Number    reader Read 0x10004 0x03  0

Should Not Read Directly From Sysbus
    Create Bus Isolation Machine

    # Because priv_aware has a requirement that the initiator is cpu0 or reader, this will not work to access it
    Command Result Should Be Number    sysbus ReadDoubleWord 0x10010  0

    # Because priv2_priv and priv2_unpriv have state requirements, this will not work to access either of them
    Command Result Should Be Number    sysbus ReadDoubleWord 0x1000c  0

    # Because priv requires that the initiator is cpu0 in a specific state, this will not work either
    Command Result Should Be Number    sysbus ReadDoubleWord 0x10004  0
