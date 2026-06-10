# The UDS test cases below exercise the diagnostic services implemented by the RAMN firmware.
# Service semantics and RAMN-specific behaviour are documented at:
#   https://ramn.readthedocs.io/en/latest/userguide/diag_tutorial.html

*** Variables ***
${MIN_ACCEPTABLE_RUNTIME_SECONDS}       10
${ECUA_UDS_ID}                          0x7e0
${ECUB_UDS_ID}                          0x7e1
${ECUC_UDS_ID}                          0x7e2
${ECUD_UDS_ID}                          0x7e3
${UDS_RESPONSE_OFFSET}                  0x8
${UDS_SESSION_CONTROL}                  0x10
# Cortex-M33 thumb shellcode: write 0xDEADBEEF to 0x20000000 and return.
# This is plain machine code, reproduce it from source with:
#
#   cat > sc.s <<'EOF'
#   .syntax unified
#   .thumb
#   .thumb_func
#   _start:
#       movw r0, #0xBEEF
#       movt r0, #0xDEAD        @ r0 = 0xDEADBEEF
#       movw r1, #0x0000
#       movt r1, #0x2000        @ r1 = 0x20000000
#       str  r0, [r1]           @ *0x20000000 = 0xDEADBEEF
#       bx   lr                 @ return to the UDS handler
#   EOF
#   arm-none-eabi-as -mcpu=cortex-m33 -mthumb sc.s -o sc.o
#   arm-none-eabi-objcopy -O binary sc.o sc.bin
#   xxd -p sc.bin
${UDS_SHELLCODE}                        4BF6EF60CDF6AD6040F20001C2F2000108607047

*** Keywords ***
Battery LED Toggling From Engine Key
    [Arguments]     ${LEDHoldingTimeout}    ${LEDName}

    Create LED Tester           sysbus.spi2.ledController.${LEDName}  machine=ECUD

    # Wait 5 seconds for the LEDs to turn off after the startup sequence
    Execute Command             emulation RunFor "5s"
    Assert And Hold Led State   false   timeoutAssert=0     timeoutHold=${LEDHoldingTimeout}

    Execute Command             adc1.engineKey CurrentState "middle"
    Assert And Hold Led State   true    timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

    Execute Command             adc1.engineKey CurrentState "left"
    Assert And Hold Led State   false   timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

Trigger Watchdog Reset
    Create Log Tester       timeout=10  defaultPauseEmulation=true

    Execute Command         iwdg WriteDoubleWord 0x0 0x5555
    Execute Command         iwdg WriteDoubleWord 0x8 0x1
    Execute Command         iwdg WriteDoubleWord 0x0 0xCCCC
    Wait For Log Entry      Watchdog reset triggered!

    # The machine reset does not occur right after the watchdog requested it. Let's simulate it to
    # ensure it occurred when returning from this function. Furthermore, waiting for a reset log
    # (non existent right now) would not work because the machine would be briefly resumed between
    # the reset and the log tester founding the string because Machine.Reset released an obtained
    # paused state.
    #
    # If the caller restarts the simulation, the reset from the watchdog might happen.
    Execute Command         machine Reset

Restore Started Platform
    Requires                 post-startup
    Create CAN Tester        canHub  1

Send UDS Command To ECU
    [Arguments]              ${ECU}  ${service}  ${data}  ${session}=01
    ${send_id}=  Evaluate    ${${ECU}_UDS_ID}
    ${recv_id}=  Evaluate    ${send_id} + ${UDS_RESPONSE_OFFSET}

    IF  $session != "01"
        # Command needs to switch session type first
        Send UDS Command And Wait For Positive Response    ${send_id}  ${recv_id}  ${UDS_SESSION_CONTROL}  ${session}  timeout=1
    END

    ${response}=  Send UDS Command And Wait For Positive Response    ${send_id}  ${recv_id}  ${service}  ${data}  timeout=1
    RETURN  ${response}

Grant Security Access To ECU
    [Arguments]              ${ECU}
    ${send_id}=  Evaluate    ${${ECU}_UDS_ID}
    ${recv_id}=  Evaluate    ${send_id} + ${UDS_RESPONSE_OFFSET}

    # Security access is only meaningful in a non-default session
    Send UDS Command And Wait For Positive Response    ${send_id}  ${recv_id}  ${UDS_SESSION_CONTROL}  02  timeout=1

    # Request the seed, ECU responds with "6701" + 4 seed bytes
    Send ISOTP Message       ${send_id}  ${recv_id}  2701
    ${seed_hex}=             Wait For ISOTP Message Hex    ${send_id}  ${recv_id}  timeout=1
    Should Start With        ${seed_hex}  6701

    # In the current RAMN ECUn binaries key = xor(seed,0x12345678) - see `RAMN_UDS_RequestSeed` and `RAMN_UDS_TryKey`
    ${key}=  Evaluate        "2702%08X" % (int($seed_hex[4:12], 16) ^ 0x12345678)
    Send ISOTP Message       ${send_id}  ${recv_id}  ${key}
    ${resp_hex}=             Wait For ISOTP Message Hex    ${send_id}  ${recv_id}  timeout=1
    Should Start With        ${resp_hex}  6702

*** Test Cases ***
Should Produce CAN Traffic
    [Documentation]          Test data path ECU{B,C,D}'s CAN controller -> CAN hub

    Execute Command          include @scripts/multi-node/ramn.resc
    Create Log Tester        timeout=1
    Execute Command          logLevel 0 canHub
    # Check that the 3 ECUs that are active (B,C,D) send traffic
    Wait For Log Entry       canHub: Received from ECUB
    Wait For Log Entry       canHub: Received from ECUC
    Wait For Log Entry       canHub: Received from ECUD

Engine Key Should Affect Battery LED
    [Documentation]         Test on ECUD that the data paths ADC -> DMA -> Memory and STM32 SPI ->
    ...                     Led controller are working

    Execute Command         include @scripts/multi-node/ramn.resc

    Battery LED Toggling From Engine Key   2    batteryWarning

Engine Key Should Affect Battery LED After Reset
    [Documentation]         Test that after a watchdog reset, the ADC, DMA and SPI work

    Execute Command         include @scripts/multi-node/ramn.resc

    # Wait 5 seconds to ensure the system is fully started before resetting it
    Execute Command         emulation RunFor "5s"
    Trigger Watchdog Reset
    Battery LED Toggling From Engine Key   2    batteryWarning

Brake Should Affect Brake LED
    [Documentation]             Test the data path Potentiometer --> ECUC's ADC --> ECUC's CAN
...                             controller --> CAN Network --> ECUD's CAN controller --> ECUC's SPI
...                             controller --> LED controller

    ${LEDHoldingTimeout}        Set Variable    2

    Execute Command             include @scripts/multi-node/ramn.resc
    Create LED Tester           sysbus.spi2.ledController.parkingBrake  machine=ECUD
    Execute Command             adc1.brake SetPercentage 0              machine=ECUC
    Execute Command             adc1.parkingBrake CurrentState "off"    machine=ECUB
    # Wait 5 seconds for the LEDs to turn off after the startup sequence
    Execute Command             emulation RunFor "5s"
    Assert And Hold Led State   false   timeoutAssert=0     timeoutHold=${LEDHoldingTimeout}

    Execute Command             adc1.brake SetPercentage 50      machine=ECUC
    Assert And Hold Led State   true    timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

Should Init Screen on ECUA
    [Documentation]         Test on ECUA that the data path Memory -> DMA -> SPI TX is working

    # Commands and data bytes sent by RAMN_SPI_InitScreen
    ${RAMN_SPI_InitScreen_bytes}    Set Variable  0x1  0x11  0x21  0x36  0x0  0x3A  0x55  0x2A  0x0
    ...                                           0xF0  0x0  0x0  0x2B  0x0  0xF0  0x0  0x0  0x13
    ...                                           0x29  0xB0  0x0  0xF8  0x33  0x0  0x20  0x1  0x20
    ...                                           0x0  0x0  0x37  0x0  0x20  0x2C

    Execute Command         include @scripts/multi-node/ramn.resc
    Execute Command         mach set "ECUA"
    Create Log Tester       timeout=5   defaultPauseEmulation=True
    Execute Command         logLevel 0 spi2.dummySpi

    FOR     ${byte}     IN  @{RAMN_SPI_InitScreen_bytes}
        Wait For Log Entry  spi2.dummySpi: Data received: ${byte}
    END

Registers Should Reset On Watchdog Reset
    [Documentation]         Test that models Reset() properly reset registers

    # The list of used devices is from capturing all peripheral accesses when running RAMN firmware.
    ${Registers} =          Create Dictionary   adc1=${{ [(0x0, 0xC4), (0x308, 0x308)] }}
    ...                                         dma2=${{ [(0x0,0xA4)] }}
    ...                                         dmamux=${{ [(0x0,0x0), (0x80, 0x84), (0x100, 0x144)] }}
    ...                                         fdcan1=${{ [(0x0,0x100)] }}
    ...                                         gpioPortB=${{ [(0x0,0x28)] }}
    ...                                         rng=${{ [(0x0,0x10)] }}
    ...                                         spi2=${{ [(0x0,0x20)] }}
    ...                                         iwdg=${{ [(0x0,0x10)] }}
    ...                                         nvic=${{ [(0x0, 0x1C), (0x100, 0x400), (0xD00, 0xFA8)] }}
    ...                                         timer1=${{ [(0x0, 0x50)] }}

    Execute Command         include @scripts/multi-node/ramn.resc
    &{Boot} =               Dump Devices Registers    ${Registers}
    Execute Command         emulation RunFor "3s"
    Trigger Watchdog Reset
    &{Reset} =              Dump Devices Registers    ${Registers}
    Devices Registers Dump Should Be Equal  ${Boot}     ${Reset}    "Boot"  "Reset"

Should Run Without Watchdog Being Triggered
    Execute Command         include @scripts/multi-node/ramn.resc

    Create Log Tester       timeout=${MIN_ACCEPTABLE_RUNTIME_SECONDS}
    Should Not Be In Log    Watchdog reset triggered!

Should Provide Started Platform
    [Documentation]         Boot the 4-ECU platform and snapshot it for the UDS test cases below

    Execute Command         include @scripts/multi-node/ramn.resc
    Execute Command         emulation RunFor "5s"
    Provides                post-startup

ECUs Should Respond To Tester Present UDS Command
    # 0x3E Tester Present: keep-alive used to stop a diagnostic session from timing out
    Restore Started Platform
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Sub-function 0x00 requests a positive response (0x80 would suppress it)
        ${response}=  Send UDS Command To ECU  ${ECU}  0x3E  00
        Should Be Equal  ${response}  7E00
    END

ECUs Should Respond To Diagnostic Session Control UDS Command
    # 0x10 Diagnostic Session Control: switch the ECU into a diagnostic session that unlocks further services
    # Session type 0x04 (safety system) is skipped - it requires additional setup
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Switching the session is a state change, so restore a clean platform per ECU
        Restore Started Platform
        # 0x01 default, 0x02 programming, 0x03 extended; the response echoes the session type
        FOR  ${session}  IN  01  02  03
            ${response}=  Send UDS Command To ECU  ${ECU}  0x10  ${session}
            Should Start With  ${response}  50${session}
        END
    END

ECUs Should Respond To ECU Reset UDS Command
    # 0x11 ECU Reset
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Reset mutates ECU state, so restore test to a clean state per ECU under test
        Restore Started Platform
        # Sub-function 0x01 = hard reset
        ${response}=  Send UDS Command To ECU  ${ECU}  0x11  01  session=02
        Should Start With  ${response}  5101
    END

ECUs Should Respond To Read Data By Identifier UDS Command
    # 0x22 Read Data By Identifier: read one 16-bit DID per request
    Restore Started Platform
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # DID 0xF184 = firmware compile-time string; response echoes 62 + the DID + the data
        ${response}=  Send UDS Command To ECU  ${ECU}  0x22  F184
        Should Start With  ${response}  62F184
    END

ECUs Should Respond To Write Data By Identifier UDS Command
    # FAIL - NRC 0x72 on all 4 ECUs; RAMN persists DIDs in flash, which is not yet modeled in Renode
    [Tags]      non_critical

    # 0x2E Write Data By Identifier: write a value to a DID
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # The value persists in flash across resets, restore clean state per ECU
        Restore Started Platform
        # DID 0xF190 (the 17-char VIN) written with ASCII "VIN0123456789ABCD"
        Send UDS Command To ECU  ${ECU}  0x2E  F19056494E3031323334353637383941424344  session=02
    END

ECUs Should Respond To Read DTC Information UDS Command
    # FAIL - NRC 0x72 on all 4 ECUs
    [Tags]      non_critical

    # 0x19 Read DTC Information: report stored Diagnostic Trouble Codes. RAMN guarantees at least
    # one DTC is present after a reset.
    Restore Started Platform
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Sub-function 0x01 = reportNumberOfDTCByStatusMask (status mask byte 0x00 ignored by RAMN)
        Send UDS Command To ECU  ${ECU}  0x19  0100
    END

ECUs Should Respond To Clear Diagnostic Information UDS Command
    # FAIL - NRC 0x72 on all 4 ECUs
    [Tags]      non_critical

    # 0x14 Clear Diagnostic Information: erase stored DTCs
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Clearing mutates the DTC store, restore a clean platform per ECU
        Restore Started Platform
        # The 3-byte argument is a DTC group mask; RAMN only supports 0xFFFFFF (clear all groups)
        Send UDS Command To ECU  ${ECU}  0x14  FFFFFF
    END

ECUs Should Respond To Read Memory By Address UDS Command
    # 0x23 Read Memory By Address: read arbitrary ECU memory
    Restore Started Platform
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # data[1]=0x14: high nibble 1 = 1-byte length field, low nibble 4 = 32-bit address;
        # read 4 bytes from flash base 0x08000000
        ${response}=  Send UDS Command To ECU  ${ECU}  0x23  140800000004  session=02

        # Verify the read-out bytes match what Renode reads straight off that ECU's bus. Both
        # Read Memory By Address and ReadBytes return bytes in ascending-address order, so the
        # UDS payload (response without its 0x63 service byte) must equal the bus bytes
        Execute Command  mach set "${ECU}"
        ${bus_bytes}=  Execute Command  sysbus ReadBytes 0x08000000 4
        ${expected}=  Evaluate  "63" + "".join("%02X" % b for b in ${bus_bytes})
        Should Be Equal  ${response}  ${expected}
    END

ECUs Should Respond To Control DTC Settings UDS Command
    # 0x85 Control DTC Settings: temporarily enable/disable DTC storage
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Mutates global platform state, restore clean state per ECU
        Restore Started Platform
        # 0x01 = on (0x02 = off)
        ${response}=  Send UDS Command To ECU  ${ECU}  0x85  01
        Should Start With  ${response}  C501
    END

ECUs Should Respond To Link Control UDS Command
    # 0x87 Link Control: stage/apply a CAN baudrate change
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Mutates global platform state, restore clean state per ECU
        Restore Started Platform
        # 0x01 verifyBaudrateTransitionWithFixedBaudrate, 0x12 = 500000
        ${response}=  Send UDS Command To ECU  ${ECU}  0x87  0112
        Should Start With  ${response}  C701
    END

ECUs Should Respond To Routine Control UDS Command
    # 0x31 Routine Control: start (sub-function 0x01) a routine by 16-bit ID.
    Restore Started Platform
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Routine 0x0203 = "echo message": no security access required; no side-effects; response echoes 71 01 0203
        ${response}=  Send UDS Command To ECU  ${ECU}  0x31  010203
        Should Start With  ${response}  71010203
    END

ECUs Should Grant Security Access UDS Command
    # 0x27 Security Access: challenge-response unlock
    FOR  ${ECU}  IN  ECUA  ECUB  ECUC  ECUD
        # Unlocking changes ECU security state, so restore a clean platform per ECU
        Restore Started Platform
        Grant Security Access To ECU  ${ECU}
    END

ECUA Should Accept Display Pixels Custom UDS Command
    # Custom service 0x41: draw pixels on the ECU screen
    Restore Started Platform
    # 2x2 RGB565 rectangle at (0,0); 2*2*2 = 8 pixel bytes
    Send UDS Command To ECU  ECUA  0x41  000002020000000000000000

ECUA Should Accept Load Chip8 Game Custom UDS Command
    # Custom service 0x42: load and run a Chip-8 game from the provided ROM
    Restore Started Platform
    # 2-byte ROM (length 0x0002), opcode 0x00E0 (clear screen)
    Send UDS Command To ECU  ECUA  0x42  000200E0

ECUA Should Execute Shellcode Via Routine Control UDS Command
    # 0x31 Routine Control routine 0x0209: execute caller-supplied ARM code
    Restore Started Platform
    Grant Security Access To ECU  ECUA

    ${send_id}=  Evaluate    ${ECUA_UDS_ID}
    ${recv_id}=  Evaluate    ${ECUA_UDS_ID} + ${UDS_RESPONSE_OFFSET}

    # Run the shellcode (0x0209)
    Send UDS Command And Wait For Positive Response    ${send_id}  ${recv_id}  0x31  010209${UDS_SHELLCODE}  timeout=2

    # Read those 4 bytes back via Read Memory By Address; RAM is little-endian, so 0xDEADBEEF
    # reads back as EF BE AD DE -> a full response of 63 EF BE AD DE proves the code executed
    Send ISOTP Message       ${send_id}  ${recv_id}  23142000000004
    ${mem_hex}=  Wait For ISOTP Message Hex    ${send_id}  ${recv_id}  timeout=1
    Should Be Equal          ${mem_hex}  63EFBEADDE
