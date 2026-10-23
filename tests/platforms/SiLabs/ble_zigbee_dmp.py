import re

import test_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000010
PROMPT = "DMPLight>"
PAN_ID = 0xABCD
POWER = 0
CHANNEL = 15
BLE_CHARACTERISTIC_ID = 31
NUM_ZIGBEE_PACKETS = 10
STUBS = [
    "sl_zigbee_af_stack_status_cb",
    "sl_zigbee_af_post_attribute_change_cb",
    "enableBleAdvertisements",
]
DEBUG = True

################################################
# Utility functions
################################################

def form_network(node, pan_id, power, channel):
    test_lib.write_line(node, f"plugin network-creator form 0 {pan_id} {power} {channel}")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    return line[-6:]

def join_network(node):
    test_lib.write_line(node, "plugin network-steering start 1")
    test_lib.wait_for(node, "NWK Steering: Start:")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    test_lib.wait_for(node, "Join Success \\(0x00\\)")
    return line[-6:]

def open_network(node):
    test_lib.write_line(node, "plugin network-creator-security open-network")
    test_lib.wait_for(node, "Open network: 0x00")
    test_lib.wait_for(node, "NETWORK_OPENED")

def leave_network(node):
    test_lib.write_line(node, "plugin network-steering stop")
    test_lib.wait_for(node, "NWK Steering: Stop")
    test_lib.write_line(node, "plugin network-creator stop")
    test_lib.wait_for(node, "NWK Creator: Stop")
    test_lib.write_line(node, "network leave")
    line = test_lib.wait_for(node, "leave 0x.")
    if "0x0" in line:
        test_lib.wait_for(node, "NETWORK_DOWN")

def run_throughput_test(node, dest_node_id):
    test_lib.write_line(node, f"network_test start_zigbee_test 70 {NUM_ZIGBEE_PACKETS} 0 3 {dest_node_id} 0x00")
    test_lib.wait_for(node, "ZigBee TX test started")
    line = test_lib.wait_for(node, "Success messages:.*out of " + str(NUM_ZIGBEE_PACKETS))
    passing = int(line.split(": ")[1].split(" ")[0])
    assert passing / NUM_ZIGBEE_PACKETS >= 0.8

def restart_ble_stack(node):
    test_lib.write_line(node, "plugin ble stop")
    test_lib.wait_for(node, "Stopping Bluetooth Stack: success")
    test_lib.write_line(node, "plugin ble start")
    test_lib.wait_for(node, "BLE hello: success")
    # Wait for the complete line; wait_for matches partial UART output by default.
    line = test_lib.wait_for(node, r"BLE address: \[.+\]", endline=True)
    m = re.search(r"BLE address: \[(.+)\]", line)
    assert m, f"Failed to parse BLE address from: {line!r}"
    ble_id = m.group(1)
    test_lib.write_line(node, "plugin ble gap set-conn-params 0x00C8 0x00C8 0x0000 0x0064")
    test_lib.wait_for(node, "success")
    return ble_id

def start_ble_advertising(node):
    test_lib.write_line(node, "plugin ble gap set-mode 0 2 2")
    test_lib.wait_for(node, "success")

def create_ble_connection(node, peer_addr):
    test_lib.write_line(node, f"plugin ble gap conn-open {{{peer_addr}}} 0")
    test_lib.wait_for(node, "success")
    test_lib.wait_for(node, "BLE connection opened")

def check_ble_connection(node, peer_addr):
    test_lib.write_line(node, "plugin ble gap print-connections")
    test_lib.wait_for(node, "Connection Info")
    test_lib.wait_for(node, f"BLE address: \\[{peer_addr}\\]", endline=True)

def get_ble_connection_handle(node, peer_addr):
    test_lib.write_line(node, "plugin ble gap print-connections")
    test_lib.wait_for(node, "Connection Info")
    line = test_lib.wait_for(node, "connection handle", endline=True)
    handle = line[-4:]
    test_lib.wait_for(node, f"BLE address: \\[{peer_addr}\\]", endline=True)
    return handle

def send_ble_test_message(tx_node, rx_node, connection_handle, value):
    test_lib.write_line(tx_node, f"plugin ble gatt write-characteristic {connection_handle} {BLE_CHARACTERISTIC_ID} {{0{value}}}")
    test_lib.wait_for(tx_node, "success")
    test_lib.wait_for(rx_node, f"Light state write; {value}")

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
# Test
################################################

board1, board2, uart1, uart2, elf1, elf2 = parse_arguments()
test_lib.create_emulation(debug=DEBUG, quantum_time=QUANTUM_TIME)

node1 = test_lib.create_node("node1", board1, elf1, uart1, function_stubs=STUBS)
node2 = test_lib.create_node("node2", board2, elf2, uart2, function_stubs=STUBS)

test_lib.wait_for(node1, PROMPT)
test_lib.wait_for(node2, PROMPT)

node1_short_id = form_network(node1, PAN_ID, POWER, CHANNEL)
open_network(node1)
node2_short_id = join_network(node2)

run_throughput_test(node1, node2_short_id)
run_throughput_test(node2, node1_short_id)

node1_ble_id = restart_ble_stack(node1)
node2_ble_id = restart_ble_stack(node2)
start_ble_advertising(node2)
create_ble_connection(node1, node2_ble_id)

check_ble_connection(node1, node2_ble_id)
check_ble_connection(node2, node1_ble_id)

node1_conn_handle = get_ble_connection_handle(node1, node2_ble_id)
node2_conn_handle = get_ble_connection_handle(node2, node1_ble_id)

send_ble_test_message(node1, node2, node1_conn_handle, 1)
send_ble_test_message(node2, node1, node2_conn_handle, 0)

run_throughput_test(node1, node2_short_id)
run_throughput_test(node2, node1_short_id)

leave_network(node1)
leave_network(node2)

check_ble_connection(node1, node2_ble_id)
check_ble_connection(node2, node1_ble_id)

node2_short_id = form_network(node2, PAN_ID, POWER, CHANNEL)
open_network(node2)
node1_short_id = join_network(node1)

check_ble_connection(node1, node2_ble_id)
check_ble_connection(node2, node1_ble_id)

run_throughput_test(node1, node2_short_id)
run_throughput_test(node2, node1_short_id)

send_ble_test_message(node1, node2, node1_conn_handle, 0)
send_ble_test_message(node2, node1, node2_conn_handle, 1)

check_ble_connection(node1, node2_ble_id)
check_ble_connection(node2, node1_ble_id)
