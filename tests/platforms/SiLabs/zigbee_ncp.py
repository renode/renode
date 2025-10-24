from common import test_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000050
PROMPT = "zigbee_z3_gateway>"
PAN_ID = 0xABCD
POWER = 0
CHANNEL = 15
NUM_ZIGBEE_PACKETS = 10
DEBUG = True

################################################
# Utility functions
################################################

def form_network(node, pan_id, power, channel):
    test_lib.write_line(node, f"plugin network-creator form 0 {pan_id} {power} {channel}")
    line = test_lib.wait_for(node, "Form: 0x00")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    return line[-6:]

def join_network(node):
    test_lib.write_line(node, "plugin network-steering start 1")
    test_lib.wait_for(node, "NWK Steering: Start:")
    line = test_lib.wait_for(node, "NETWORK_UP 0x....")
    test_lib.wait_for(node, "Join Success")
    return line[-6:]

def open_network(node):
    test_lib.write_line(node, "plugin network-creator-security open-network")
    test_lib.wait_for(node, "Open network: 0x00")
    test_lib.wait_for(node, "NETWORK_OPENED")

def send_test_message(sender, receiver, receiver_short_id):
    test_lib.write_line(sender, "zcl global read 0x0006 0x0")
    test_lib.wait_for(sender, "buffer")
    test_lib.write_line(sender, f"send {receiver_short_id} 1 1")
    test_lib.wait_for(receiver, "RX len 5, ep 01, clus 0x0006 \\(On/off\\)")
    test_lib.wait_for(receiver, "READ_ATTR: clus 0006")

################################################
# Test
################################################

ncp_board, ncp_uart, ncp_elf, host_binary = test_lib.parse_arguments()
test_lib.create_emulation(debug=DEBUG, quantum_time=QUANTUM_TIME)
# It appears that Zigbee HOST processes don't flush out their output.
# In order to ensure we receive the whole output, enable output flushing, which
# periodically sends a new line character to the HOST process.
test_lib.enable_output_flushing(True)

# Node-1 HOST/NCP
ncp1 = test_lib.create_node("ncp1", ncp_board, ncp_elf, ncp_uart)
ncp1_pty = test_lib.create_pty_terminal(ncp1, ncp_uart)
host1 = test_lib.launch_host_process(host_binary,
                                     "host1",
                                     "-p " + ncp1_pty)

# Node-2 HOST/NCP
ncp2 = test_lib.create_node("ncp2", ncp_board, ncp_elf, ncp_uart)
ncp2_pty = test_lib.create_pty_terminal(ncp2, ncp_uart)
host2 = test_lib.launch_host_process(host_binary,
                                     "host2",
                                     "-p " + ncp2_pty)

test_lib.wait_for(host1, PROMPT)
test_lib.wait_for(host2, PROMPT)

node1_short_id = form_network(host1, PAN_ID, POWER, CHANNEL)
open_network(host1)
node2_short_id = join_network(host2)

send_test_message(host1, host2, node2_short_id)
send_test_message(host2, host1, node1_short_id)