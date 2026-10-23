import test_lib
from common import openthread_lib

################################################
# Globals
################################################

QUANTUM_TIME = 0.000020
CSL_PERIOD = 500000
CSL_TIMEOUT = 30
PROMPT = "> "
DEBUG = True

################################################
# Utility functions
################################################

def wait_for_boot(node):
    test_lib.wait_for(node, "Reset info:")
    test_lib.wait_for(node, "Extended Reset info:")
    test_lib.write_line(node, "")
    test_lib.wait_for(node, PROMPT)

# Supports passing both a single board/UART/ELF and a pair of boards/UARTs/ELFs
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

node1 = test_lib.create_node("node1", board1, elf1, uart1)
node2 = test_lib.create_node("node2", board2, elf2, uart2)

wait_for_boot(node1)
wait_for_boot(node2)

network_key, channel, panid = openthread_lib.leader_start(node1)
openthread_lib.router_start(node2, network_key, channel, panid, csl_enabled=True, csl_period=CSL_PERIOD, csl_timeout=CSL_TIMEOUT)

openthread_lib.ping_test(node1, node2)
openthread_lib.ping_test(node2, node1)

openthread_lib.coaps_test(node1, node2)
