import test_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000020
TESTER_TIMEOUT = 1
PROMPT = ">"
DEBUG = True

################################################
# Utility functions
################################################

def send_packet(tx_node, rx_node, expect_rx):
    test_lib.write_line(tx_node, "tx 1")
    if expect_rx:
        test_lib.wait_for(rx_node, "\\(rxPacket\\)", endline=True)
    else:
        test_lib.assert_not_received(rx_node, "\\(rxPacket\\)")
    test_lib.wait_for(tx_node, "\\(txEnd\\)", endline=True)

def enable_rx(node, enable):
    test_lib.write_line(node, f"rx {1 if enable else 0}")
    if enable:
        test_lib.wait_for(node, "\\{Rx:Enabled\\}\\{Idle:Disabled\\}", endline=True)
    else:
        test_lib.wait_for(node, "\\{Rx:Disabled\\}\\{Idle:Enabled\\}", endline=True)

def set_channel(node, channel):
    test_lib.write_line(node, f"setChannel {channel}")
    test_lib.wait_for(node, f"\\{{channel:{channel}\\}}", endline=True)

def check_radio_state(node, state):
    test_lib.write_line(node, "getRadioState")
    test_lib.wait_for(node, f"radioState:{state}", endline=True)

def configure_802154_mode(node):
    test_lib.write_line(node, "enable802154 rx 100 192 864")
    test_lib.wait_for(node, "\\{idleTiming:100\\}\\{turnaroundTime:192\\}\\{ackTimeout:864\\}")
    test_lib.write_line(node, "config2p4GHz802154")
    test_lib.wait_for(node, "\\{802.15.4:Enabled\\}")
    test_lib.write_line(node, "acceptFrames 1 1 1 1")
    test_lib.wait_for(node, "\\{CommandFrame:Enabled\\}\\{AckFrame:Enabled\\}\\{DataFrame:Enabled\\}\\{BeaconFrame:Enabled\\}")
    test_lib.write_line(node, "setPromiscuousMode 0")
    test_lib.wait_for(node, "\\{PromiscuousMode:Disabled\\}")

def set_802154_fields(node, pan_id, short_id):
    test_lib.write_line(node, f"setpanid802154 {pan_id} 0")
    test_lib.wait_for(node, "\\{802.15.4PanId:Success\\}")
    test_lib.write_line(node, f"setshortaddr802154 {short_id} 0")
    test_lib.wait_for(node, "\\{802.15.4ShortAddress:Success\\}")

# Supports passing both a single board/UART/ELF and a pair of boards/UARTs/ELFs.
# If only a single board/UART/ELF is passed, it will be used for both nodes.
def parse_arguments():
    boards, uarts, elfs = test_lib.parse_arguments()
    board1 = boards[0]
    board2 = boards[1] if len(boards) > 1 else board1
    uart1 = uarts[0]
    uart2 = uarts[1] if len(uarts) > 1 else uart1
    elf1 = elfs[0]
    elf2 = elfs[1] if len(elfs) > 1 else elf1
    return board1, board2, uart1, uart2, elf1, elf2

################################################
# Main
################################################

board1, board2, uart1, uart2, elf1, elf2 = parse_arguments()
test_lib.create_emulation(debug=DEBUG, quantum_time=QUANTUM_TIME)

node1 = test_lib.create_node("node1", board1, elf1, uart1, tester_timeout=TESTER_TIMEOUT)
node2 = test_lib.create_node("node2", board2, elf2, uart2, tester_timeout=TESTER_TIMEOUT)

test_lib.wait_for(node1, PROMPT)
test_lib.wait_for(node2, PROMPT)

################################################
# Basic Communication Test

check_radio_state(node1, "Rx")
check_radio_state(node2, "Rx")

# Nodes on the same channel: send packets, expect reception
set_channel(node1, 5)
set_channel(node2, 5)
send_packet(node1, node2, True)
send_packet(node2, node1, True)

# Nodes on different channels: send packets, expect NO reception
set_channel(node2, 7)
send_packet(node1, node2, False)
send_packet(node2, node1, False)

# Nodes on the same channel: send packets, expect reception
set_channel(node2, 5)
send_packet(node1, node2, True)
send_packet(node2, node1, True)

# Node 2 radio is off: send a packet, expect NO reception
enable_rx(node2, False)
check_radio_state(node2, "Idle")
send_packet(node1, node2, False)

################################################
# Auto ACK Test

# Node 1 (RX) config
enable_rx(node1, False)
configure_802154_mode(node1)
set_channel(node1, 24)
set_802154_fields(node1, "0x5555", "0xAAAA")
enable_rx(node1, True)

# Node 2 (TX) config
enable_rx(node2, False)
configure_802154_mode(node2)
set_channel(node2, 24)
test_lib.write_line(node2, "configTxOptions 1")
test_lib.wait_for(node2, "\\{waitForAck:True\\}")

# Node 2 TX a packet to Node 1, gets an ACK back
test_lib.write_line(node2, "settxpayload 0 14 0x23 0x88 0xbe 0x55 0x55 0xAA 0xAA 0x55 0x55 0xAA 0xAA 0x04")
test_lib.write_line(node2, "tx 1")
test_lib.wait_for(node2, "\\(rxPacket\\).*\\{isAck:True\\}", endline=True)

