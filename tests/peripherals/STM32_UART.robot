*** Variables ***
${STATUS_REGISTER}                  0x0
${DATA_REGISTER}                    0x4
${BAUD_RATE_REGISTER}               0x8
${CONTROL_REGISTER_1}               0xC
${IDLE_LINE_DETECTED}               0x10
${RECEIVE_REGISTER_NOT_EMPTY}       0x20
${TIME_QUANTUM_SECONDS}             0.000001
# The default 8N1 frame has one start bit, eight data bits, and one stop bit.
# At 1 Mbaud, these 10 bits take 10 us.
${FRAME_DURATION_SECONDS}           0.000010
${TIME_BEFORE_FRAME_END_SECONDS}    ${{ "{:.6f}".format(${FRAME_DURATION_SECONDS} - ${TIME_QUANTUM_SECONDS}) }}

*** Keywords ***
Create Machine
    [Arguments]                     ${control_register_1_value}=0x2004
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "uart: UART.STM32_UART @ sysbus <0x40000000, +0x100> { frequency: 16000000 }"
    # Set UART enable (UE) and receiver enable (RE).
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} ${control_register_1_value}
    # A 16 MHz clock and a 0x10 divider configure a baud rate of 1 Mbaud.
    Execute Command                 uart WriteDoubleWord ${BAUD_RATE_REGISTER} 0x10
    Execute Command                 emulation SetGlobalQuantum "${TIME_QUANTUM_SECONDS}"

Receive Register Should Be Empty
    ${status}=                      Execute Command  uart ReadDoubleWord ${STATUS_REGISTER}
    ${rxne}=                        Evaluate  ${status.strip()} & ${RECEIVE_REGISTER_NOT_EMPTY}
    Should Be Equal As Numbers      ${rxne}  0

Receive Character Should Be Equal
    [Arguments]                     ${expected}
    ${value}=                       Execute Command  uart ReadDoubleWord ${DATA_REGISTER}
    Should Be Equal As Numbers      ${value}  ${expected}

Idle Line Should Not Be Detected
    ${status}=                      Execute Command  uart ReadDoubleWord ${STATUS_REGISTER}
    ${idle}=                        Evaluate  ${status.strip()} & ${IDLE_LINE_DETECTED}
    Should Be Equal As Numbers      ${idle}  0

Idle Line Should Be Detected
    ${status}=                      Execute Command  uart ReadDoubleWord ${STATUS_REGISTER}
    ${idle}=                        Evaluate  ${status.strip()} & ${IDLE_LINE_DETECTED}
    Should Be Equal As Numbers      ${idle}  ${IDLE_LINE_DETECTED}

*** Test Cases ***
Should Receive Characters At Configured Baud Rate
    Create Machine

    # Write two arbitrary characters.
    Execute Command                 uart WriteChar 0x12
    Execute Command                 uart WriteChar 0x34

    # The receive register must stay empty until the first frame is complete.
    Receive Register Should Be Empty
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Receive Register Should Be Empty

    # Complete the first frame. Only the first character must be available.
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Receive Character Should Be Equal  0x12

    # The receive register must stay empty until the second frame is complete.
    Receive Register Should Be Empty
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Receive Register Should Be Empty

    # Complete the second frame. The second character must now be available.
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Receive Character Should Be Equal  0x34
    Idle Line Should Not Be Detected

    # IDLE must remain clear until one complete idle frame passes.
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Idle Line Should Not Be Detected
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Idle Line Should Be Detected

Should Account For Parity Within Word Length
    ${uart_receiver_and_parity_enabled}=  Set Variable  0x2404
    # The eight-bit word contains seven data bits and one parity bit.
    Create Machine                  ${uart_receiver_and_parity_enabled}

    Execute Command                 uart WriteChar 0x12
    # The complete frame still takes 10 us.
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Receive Register Should Be Empty
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Receive Character Should Be Equal  0x12
    Idle Line Should Not Be Detected
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Idle Line Should Not Be Detected
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Idle Line Should Be Detected

Should Preserve Character Order When Baud Rate Becomes Zero
    Create Machine

    # Queue the first character while receive pacing is active.
    Execute Command                 uart WriteChar 0x12
    # Disabling pacing must deliver the queued character before later direct input.
    Execute Command                 uart WriteDoubleWord ${BAUD_RATE_REGISTER} 0x0
    Execute Command                 uart WriteChar 0x34

    Receive Character Should Be Equal  0x12
    Receive Character Should Be Equal  0x34

Should Cancel Idle Detection When A New Frame Starts
    Create Machine

    Execute Command                 uart WriteChar 0x12
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Character Should Be Equal  0x12

    # Start a new frame immediately before the IDLE condition is detected.
    Execute Command                 emulation RunFor "${TIME_BEFORE_FRAME_END_SECONDS}"
    Idle Line Should Not Be Detected
    Execute Command                 uart WriteChar 0x34
    Execute Command                 emulation RunFor "${TIME_QUANTUM_SECONDS}"
    Idle Line Should Not Be Detected

Should Drop Queued Character When Receiver Is Disabled
    Create Machine

    # Queue a character, then disable the receiver before the frame is complete.
    Execute Command                 uart WriteChar 0x12
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x2000
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty

    # The character must not be delivered after the receiver is enabled again.
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x2004
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty

Should Drop Characters When UART Or Receiver Disabled
    Create Machine

    # Keep the UART enabled and disable the receiver.
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x2000
    Execute Command                 uart WriteChar 0x12
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty
    # The character must be dropped, not deferred until the receiver is enabled.
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x2004
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty

    # Enable the receiver and disable the UART.
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x4
    Execute Command                 uart WriteChar 0x34
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty
    # The character must be dropped, not deferred until the UART is enabled.
    Execute Command                 uart WriteDoubleWord ${CONTROL_REGISTER_1} 0x2004
    Execute Command                 emulation RunFor "${FRAME_DURATION_SECONDS}"
    Receive Register Should Be Empty
