from common import bgapi_lib
from common import test_lib
import bgapi

XAPI = "tests/platforms/SiLabs/common/sl_bt.xapi"
DEFAULT_TIMEOUT = 2
DEFAULT_INTERVAL = 0.1

terminal_testers = {}

########################################################################
# BGAPI Commands
########################################################################

def cmd_hello(tester_id):
    _execute_command(tester_id, "system.hello")

def cmd_get_identity_address(tester_id):
    return _execute_command(tester_id, "system.get_identity_address").address

def cmd_legacy_advertiser_create_set(tester_id):
    return int(_execute_command(tester_id, "advertiser.create_set").handle)

def cmd_legacy_advertiser_generate_data(tester_id, handle, mode):
    _execute_command(tester_id, "legacy_advertiser.generate_data", handle, mode)

def cmd_legacy_advertiser_start(tester_id, handle, mode):
    _execute_command(tester_id, "legacy_advertiser.start", handle, mode)

def cmd_connection_open(tester_id, address, address_type):
    l = _host_connection_lookup(tester_id)
    return _execute_command(tester_id, "connection.open", address, address_type, l.bt.gap.PHY_PHY_1M).connection

def cmd_increase_security(tester_id, handle):
    _execute_command(tester_id, "sm.increase_security", handle)

########################################################################
# Events
########################################################################

def wait_for_boot_event(tester_id):
    return _wait_for_event("bt_evt_system_boot", tester_id)

def wait_for_connection_opened_event(tester_id):
    result = _wait_for_event("bt_evt_connection_opened", tester_id)
    return result.connection

def wait_for_connection_parameters_event(tester_id):
    result = _wait_for_event("bt_evt_connection_parameters", tester_id)
    return result.connection

def wait_for_bonded_event(tester_id):
    result = _wait_for_event("bt_evt_sm_bonded", tester_id)
    return result.connection

def assert_no_connection_closed_event(tester_id):
    assert_event_not_in_queue(tester_id, "bt_evt_connection_closed")

def assert_event_not_in_queue(tester_id, event):
    while _get_pending_event(tester_id):
        if _get_pending_event(tester_id) == event:
            test_lib.fail(f"Unexpected event in queue: {event}")
    test_lib.debug_print(f"Confirmed event \"{event}\" not in queue")

########################################################################
# Host Connection
########################################################################

def open_host_connection(port):
    global terminal_testers
    connector = bgapi.SocketConnector("127.0.0.1", port)
    l = bgapi.BGLib(connector, XAPI, response_timeout=10)
    l.open()
    test_lib.debug_print(f"Opened host connection on port: {port}")
    index = len(terminal_testers)
    terminal_testers[index] = l
    return index

def close_all_host_connections():
    for i in terminal_testers:
        terminal_testers[i].close()

########################################################################
# Internals
########################################################################

def _host_connection_lookup(index):
    for i in terminal_testers:
        if index == i:
            return terminal_testers[i]
    return None

def _get_pending_event(tester_id):
    l = _host_connection_lookup(tester_id)
    for e in l.gen_events():
        return e
    return None

def _execute_command(tester_id, command, *args):
    l = _host_connection_lookup(tester_id)
    test_lib.monitor().execute("start")
    attrs = command.split(".")
    obj = l.bt
    for attr in attrs:
        obj = getattr(obj, attr)
    test_lib.debug_print(f"Executing command: {command}, with args: {args}")
    response = obj(*args)
    test_lib.debug_print(f"Command response: {response}")
    test_lib.monitor().execute("pause")
    if (response.result != 0):
        test_lib.fail(f"\"{command}\" command: response unsuccessful: {response.result}")
    return response

def _wait_for_event(event, tester_id):
    max_attempts = DEFAULT_TIMEOUT / DEFAULT_INTERVAL
    attempts = 0
    for attempts in range(int(max_attempts)):
        evt = _get_pending_event(tester_id)
        test_lib.debug_print(f"Waiting for event: {event}, Current event: {evt}")
        if evt == None:
            test_lib.delay(DEFAULT_INTERVAL)
        else:
            if evt == event:
                return evt
            else:
                test_lib.fail(f"Event mismatch: {evt} != {event}")
    test_lib.fail(f"Timeout waiting for event: {event}")
    return None