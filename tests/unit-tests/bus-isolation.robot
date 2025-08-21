*** Variables ***
${CPU0_INITIATOR_STRING}               the initiator 'cpu0'
${POSSIBLE_INITIATORS_STRING}          peripherals implementing IPeripheralWithTransactionState (initiator not specified)


*** Keywords ***
Command Result Should Be Number
    [Arguments]  ${command}  ${result}

    ${actual}=  Execute Command        ${command}
    Should Be Equal As Numbers         ${actual}  ${result}

Create Bus Isolation Machine
    Execute Script                     tests/unit-tests/bus_isolation.resc

Register With Condition And Expect Error
    [Arguments]  ${condition}  ${error}

    Run Keyword And Expect Error       *${error}*
    ...  Execute Command               machine LoadPlatformDescriptionFromString "uart: UART.PL011 @ sysbus new Bus.BusPointRegistration { address: 0x0; condition: \\"${condition}\\" }"


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
    Register Should Be Equal           1   0x63707506
    Register Should Be Equal           2   0x63707506


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
    Register Should Be Equal           1   0x63707500
    Register Should Be Equal           2   0x63707500

Should Change Access Conditions At Runtime
    Create Bus Isolation Machine

    # Execute `ldr r0, =0x10000` and `ldr r3, [r0]` (the first iteration of the first read)
    Execute Command               cpu0 Step 2
    Register Should Be Equal      3  0x1010  # Read OK because the condition in the repl is "(cpuSecure || !privileged) && initiator == cpu0"
    Register Should Be Equal      4  0       # Not reached yet

    # Now change the condition on the peripheral at 0x10000 to fail
    Execute Command               sysbus ChangePeripheralAccessCondition unpriv "initiator == cpu0 && (!cpuSecure || !privileged)"

    # The next instruction is another `ldr r3, [r0]`, which will now see 0 (open bus)
    Execute Command               cpu0 Step
    Register Should Be Equal      3  0       # Read 0 because the condition is now "(!cpuSecure || !privileged)" which fails
    Register Should Be Equal      4  0       # Not reached yet


Should Read Through Privilege Aware Reader
    Create Bus Isolation Machine

    #                                                      ↓ raw initiator state which gets passed to the peripheral
    Command Result Should Be Number    reader Read 0x10010 0x00  0x72656100
    Command Result Should Be Number    reader Read 0x10010 0x01  0x72656101
    Command Result Should Be Number    reader Read 0x10010 0xa5  0x72656105
    Command Result Should Be Number    reader Read 0x20010 0x02  0x72656102

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

Should Handle Readers And Log Context Access
    Create Bus Isolation Machine
    Create Log Tester                  1

    Command Result Should Be Number    reader Read 0x10010 0x00   0x72656100
    Wait For Log Entry                 priv_aware: Read from context

    Command Result Should Be Number    reader2 Read 0x10010 0x00  0
    Wait For Log Entry                 priv_aware: No context

    Command Result Should Be Number    reader3 Read 0x10010 0x00  0
    Wait For Log Entry                 sysbus: ReadDoubleWord from non existing peripheral at 0x10010

Should Not Read Directly From Sysbus
    Create Bus Isolation Machine

    # Because priv_aware has a requirement that the initiator is cpu0 or reader, this will not work to access it
    Command Result Should Be Number    sysbus ReadDoubleWord 0x10010  0

    # Because priv2_priv and priv2_unpriv have state requirements, this will not work to access either of them
    Command Result Should Be Number    sysbus ReadDoubleWord 0x1000c  0

    # Because priv requires that the initiator is cpu0 in a specific state, this will not work either
    Command Result Should Be Number    sysbus ReadDoubleWord 0x10004  0

Test Unsupported Condition Without Initiator
    Create Bus Isolation Machine

    Register With Condition And Expect Error
    ...  !invalid
    ...  Provided condition is unsupported by ${POSSIBLE_INITIATORS_STRING}: invalid; supported conditions: 'privileged', 'cpuSecure', 'attributionSecure'

Test Unsupported Condition With Initiator
    Create Bus Isolation Machine

    Register With Condition And Expect Error
    ...  invalid && initiator == cpu0
    ...  Provided condition is unsupported by ${CPU0_INITIATOR_STRING}: invalid; supported conditions: 'privileged', 'cpuSecure', 'attributionSecure'

Test Condition With Initiator Not Supporting States
    Create Bus Isolation Machine

    Register With Condition And Expect Error
    ...  cpuSecure && initiator == reader2 && !privileged
    ...  Conditions provided (cpuSecure && !privileged) but the initiator 'reader2' doesn't implement IPeripheralWithTransactionState or has no state bits

Test Conditions With Unregistered Initiator
    Execute Command                    mach create

    Register With Condition And Expect Error
    ...  cpuSecure && initiator == reader
    ...  Invalid initiator: reader

Test Unregistered Initiator
    Execute Command                    mach create

    Register With Condition And Expect Error
    ...  initiator == reader
    ...  Invalid initiator: reader

Test Condition With No Initiators In The Machine
    Execute Command                    mach create

    Register With Condition And Expect Error
    ...  !privileged
    ...  Conditions provided (!privileged) but there are no peripherals implementing IPeripheralWithTransactionState or they have no common state bits

Test Conflicting Conditions
    Create Bus Isolation Machine

    Register With Condition And Expect Error
    ...  cpuSecure && !cpuSecure
    ...  Conditions conflict detected for ${POSSIBLE_INITIATORS_STRING}: cpuSecure
