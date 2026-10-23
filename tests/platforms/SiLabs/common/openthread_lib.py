import re

import test_lib

def set_log_level(node, level):
    test_lib.write_line(node, f"log level {level}")
    test_lib.wait_for(node, "Done")

def leader_start(node):
    test_lib.write_line(node, "dataset init new")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "dataset commit active")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "ifconfig up")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "thread start")
    test_lib.wait_for(node, "Role detached -> leader")
    test_lib.write_line(node, "state")
    test_lib.wait_for(node, "leader")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "dataset networkkey")
    key = test_lib.wait_for(node, r"^[0-9a-fA-F]{32}$", endline=True)
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "dataset channel")
    channel = test_lib.wait_for(node, r"^\d{1,2}$", endline=True)
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "dataset panid")
    panid = test_lib.wait_for(node, r"^0x[0-9a-fA-F]{4}$", endline=True)
    test_lib.wait_for(node, "Done")
    return key, channel, panid

def router_start(node, key, channel, panid, csl_enabled=False, csl_period=500000, csl_timeout=30):
    if csl_enabled:
        test_lib.write_line(node, f"csl period {csl_period}")
        test_lib.wait_for(node, "Done")
        test_lib.write_line(node, f"csl timeout {csl_timeout}")
        test_lib.wait_for(node, "Done")
        test_lib.write_line(node, "mode -")
        test_lib.wait_for(node, "Done")
    test_lib.write_line(node, f"dataset channel {channel}")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, f"dataset panid {panid}")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, f"dataset networkkey {key}")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "dataset commit active")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "ifconfig up")
    test_lib.wait_for(node, "Done")
    test_lib.write_line(node, "thread start")
    test_lib.wait_for(node, "Role detached -> child", 30)
    # TODO: for now we don't wait for the transition from child to router since the
    # default timing is very long. The timing could be reduced from CLI.
    # test_lib.wait_for(node, "Role child -> router", 100)
    # test_lib.write_line(node, "state")
    # test_lib.wait_for(node, "router")
    # test_lib.wait_for(node, "Done")

def get_ipv6_address(node):
    # ot-cli's "> " prompt has no trailing newline, so it can glue onto the
    # next response line. Match the address anywhere on the line.
    test_lib.write_line(node, "ipaddr linklocal")
    line = test_lib.wait_for(node, r".*([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}", endline=True)
    test_lib.wait_for(node, "Done")
    return re.search(r"([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}", line).group(0)

def ping_test(pinger, pinged):
    ipv6_addr = get_ipv6_address(pinged)
    test_lib.write_line(pinger, f"ping {ipv6_addr}")
    test_lib.wait_for(pinger, "1 packets transmitted, 1 packets received")
    test_lib.wait_for(pinger, "Done")

def coaps_test(node1, node2, timeout=10):
    test_lib.write_line(node1, "coaps x509")
    test_lib.wait_for(node1, "Done")
    test_lib.write_line(node1, "coaps start")
    test_lib.wait_for(node1, "Done")
    test_lib.write_line(node1, "coaps resource testsecure42")
    test_lib.wait_for(node1, "Done")
    node1_ipv6_addr = get_ipv6_address(node1)
    test_lib.write_line(node2, "coaps x509")
    test_lib.wait_for(node2, "Done")
    test_lib.write_line(node2, "coaps start")
    test_lib.wait_for(node2, "Done")
    test_lib.write_line(node2, f"coaps connect {node1_ipv6_addr}")
    test_lib.wait_for(node1, "coaps connected", timeout)
    test_lib.wait_for(node2, "coaps connected", timeout)
