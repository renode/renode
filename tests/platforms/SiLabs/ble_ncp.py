from common import test_lib
from common import bgapi_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000020
DEBUG = True

################################################
# Utility functions
################################################

################################################
# Test
################################################

board, uart, elf = test_lib.parse_arguments()
test_lib.create_emulation(debug=DEBUG, quantum_time=QUANTUM_TIME)

# Node 1 
ncp1 = test_lib.create_node("ncp1", board, elf, uart)
test_lib.create_socket(ncp1, 3451, uart)
host1 = bgapi_lib.open_host_connection(3451)

# Node 2
ncp2 = test_lib.create_node("ncp2", board, elf, uart)
test_lib.create_socket(ncp2, 3452, uart)
host2 = bgapi_lib.open_host_connection(3452)

bgapi_lib.wait_for_boot_event(host1)
bgapi_lib.wait_for_boot_event(host2)

bgapi_lib.cmd_hello(host1)
bgapi_lib.cmd_hello(host2)

node1_address = bgapi_lib.cmd_get_identity_address(host1)
node2_address = bgapi_lib.cmd_get_identity_address(host2)

# Node 1 to start advertising
adv_handle = bgapi_lib.cmd_legacy_advertiser_create_set(host1)
bgapi_lib.cmd_legacy_advertiser_generate_data(host1, adv_handle, 2)
bgapi_lib.cmd_legacy_advertiser_start(host1, adv_handle, 2)

# Node 2 to establish a connection to Node 1
bgapi_lib.cmd_connection_open(host2, node1_address, 0)
node1_conn_handle = bgapi_lib.wait_for_connection_opened_event(host1)
node2_conn_handle = bgapi_lib.wait_for_connection_opened_event(host2)

bgapi_lib.assert_no_connection_closed_event(host1)
bgapi_lib.assert_no_connection_closed_event(host2)

# Let some time pass and check that the connection is still open
test_lib.delay(1)

bgapi_lib.assert_no_connection_closed_event(host1)
bgapi_lib.assert_no_connection_closed_event(host2)

# RENODE-517: xG22 requires missing CRYPTOACC3_PKCTRL block.
if (board != "brd4182a"):
    bgapi_lib.cmd_increase_security(host2, node2_conn_handle)
    bgapi_lib.wait_for_connection_parameters_event(host1)
    bgapi_lib.wait_for_bonded_event(host1)
    bgapi_lib.wait_for_connection_parameters_event(host2)
    bgapi_lib.wait_for_bonded_event(host2)

# Let some time pass and check that the connection is still open
test_lib.delay(3)

bgapi_lib.assert_no_connection_closed_event(host1)
bgapi_lib.assert_no_connection_closed_event(host2)
