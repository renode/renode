# BGAPI host side of the BLE NCP tests, used as a Robot keyword library
import os
import bgapi
from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn

XAPI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sl_bt.xapi")
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

def wait_for_security_increased_events(tester_id):
    # sl_bt_sm_increase_security emits both events. 2025.6.2 NCP apps report
    # connection parameters first. Later stacks report the bonded event first,
    # from encryption_changed(), and the connection parameters event after it.
    pending = ["bt_evt_connection_parameters", "bt_evt_sm_bonded"]
    while pending:
        evt = _wait_for_one_of(pending, tester_id)
        # BGEvent inherits tuple inequality, which ignores BGMsg.__eq__.
        pending = [name for name in pending if not (evt == name)]

def assert_no_connection_closed_event(tester_id):
    assert_event_not_in_queue(tester_id, "bt_evt_connection_closed")

def assert_event_not_in_queue(tester_id, event):
    while (evt := _get_pending_event(tester_id)) is not None:
        if evt == event:
            _fail(f"Unexpected event in queue: {event}")
    logger.debug(f"Confirmed event \"{event}\" not in queue")

########################################################################
# Host Connection
########################################################################

def open_host_connection(port):
    global terminal_testers
    connector = bgapi.SocketConnector("127.0.0.1", port)
    l = bgapi.BGLib(connector, XAPI, response_timeout=10)
    l.open()
    logger.debug(f"Opened host connection on port: {port}")
    index = len(terminal_testers)
    terminal_testers[index] = l
    return index

def close_all_host_connections():
    try:
        for connection in terminal_testers.values():
            try:
                connection.close()
            except Exception as e:
                logger.warn(f"Failed to close host connection: {e}")
    finally:
        terminal_testers.clear()

########################################################################
# Internals
########################################################################

def _monitor(command):
    return BuiltIn().run_keyword("Execute Command", command)

def _fail(message):
    raise AssertionError(message)


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
    attrs = command.split(".")
    obj = l.bt
    for attr in attrs:
        obj = getattr(obj, attr)
    logger.debug(f"Executing command: {command}, with args: {args}")
    _monitor("start")
    try:
        response = obj(*args)
    finally:
        _monitor("pause")
    logger.debug(f"Command response: {response}")
    if (response.result != 0):
        _fail(f"\"{command}\" command: response unsuccessful: {response.result}")
    return response

def _wait_for_event(event, tester_id):
    return _wait_for_one_of([event], tester_id)

def _wait_for_one_of(events, tester_id):
    steps = int(DEFAULT_TIMEOUT / DEFAULT_INTERVAL)
    while True:
        evt = _get_pending_event(tester_id)
        logger.debug(f"Waiting for one of: {events}, Current event: {evt}")
        if evt == None:
            if steps == 0:
                break
            steps -= 1
            _monitor(f'emulation RunFor "{DEFAULT_INTERVAL}"')
        else:
            for event in events:
                if evt == event:
                    return evt
            # The stack reports more events than the tests check, in an order that differs
            # between versions. Skip them, but don't wait through a dropped connection.
            if evt == "bt_evt_connection_closed":
                _fail(f"Connection closed while waiting for one of: {events}")
            logger.debug(f"Skipping event: {evt}")
    _fail(f"Timeout waiting for one of: {events}")
    return None
