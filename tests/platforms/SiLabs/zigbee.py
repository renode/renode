from common import test_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000050
PROMPT = "z3_light"
PAN_ID = 0xABCD
POWER = 0
CHANNEL = 15
NUM_ZIGBEE_PACKETS = 10
STUBS = ["sl_zigbee_af_main_init_cb", "sl_zigbee_af_stack_status_cb"]
DEBUG = True

################################################
# Utility functions
################################################

def reset(node):
    test_lib.write_line(node, "reset")

def form_network(node, pan_id, power, channel):
    test_lib.write_line(node, f"plugin network-creator form 0 {pan_id} {power} {channel}")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    return line[-6:]

def join_network(node):
    test_lib.write_line(node, "plugin network-steering start 1")
    test_lib.wait_for(node, "NWK Steering: Start:")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    test_lib.wait_for(node, "Join network complete: 0x00")
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
    line = line.split(": ")[1]  # Get "N out of 10"
    line = line.split(" ")[0]  # Get "N"
    assert(int(line) / NUM_ZIGBEE_PACKETS >= 0.8)

################################################
# Test
################################################

board, uart, elf = test_lib.parse_arguments()
test_lib.create_emulation(debug=DEBUG, quantum_time=QUANTUM_TIME)

node1 = test_lib.create_node("node1", board, elf, uart, function_stubs=STUBS)
node2 = test_lib.create_node("node2", board, elf, uart, function_stubs=STUBS)

test_lib.wait_for(node1, PROMPT)
test_lib.wait_for(node2, PROMPT)

# Inital form/join
node1_short_id = form_network(node1, PAN_ID, POWER, CHANNEL)
open_network(node1)
node2_short_id = join_network(node2)

# Reset nodes, they are expected to remain joined
reset(node1)
reset(node2)
test_lib.wait_for(node1, PROMPT)
test_lib.wait_for(node2, PROMPT)

# Let some time pass to allow the network to stabilize
test_lib.delay(10)

run_throughput_test(node1, node2_short_id)
run_throughput_test(node2, node1_short_id)

leave_network(node1)
leave_network(node2)

node2_short_id = form_network(node2, PAN_ID, POWER, CHANNEL)
open_network(node2)
node1_short_id = join_network(node1)

run_throughput_test(node1, node2_short_id)
run_throughput_test(node2, node1_short_id)