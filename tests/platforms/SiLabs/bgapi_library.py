import os
import select
import time
import subprocess
import logging
import bgapi

ble_host_connection_count = 0
ble_host_connections = {}

def bgapi_open_host_connection(port, bt_api):
    global ble_host_connection_count
    global ble_host_connections
    connector = bgapi.SocketConnector("127.0.0.1", port)
    l = bgapi.BGLib(connector, bt_api, response_timeout=10)
    l.open()
    ble_host_connections[ble_host_connection_count] = l
    ret = ble_host_connection_count
    ble_host_connection_count = ble_host_connection_count + 1
    return ret

def bgapi_close_all_host_connections():
    for index in ble_host_connections:
        ble_host_connections[index].close()

def bgapi_host_connection_lookup(index):
    for i in ble_host_connections:
        if index == i:
            return ble_host_connections[i]
    return None

def bgapi_get_pending_event(tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    for e in l.gen_events():
        return e
    return None

def bgapi_check_event_in_queue(evt, tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    for e in l.gen_events():
        if e == evt:
            return True
    return False

def bgapi_hello(tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.system.hello()
    return ret

def bgapi_get_identity_address(tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.system.get_identity_address()
    return ret

def bgapi_legacy_advertiser_create_set(tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.advertiser.create_set()
    return ret

def bgapi_legacy_advertiser_generate_data(handle, mode, tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.legacy_advertiser.generate_data(handle, mode)
    return ret

def bgapi_legacy_advertiser_start(handle, mode, tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.legacy_advertiser.start(handle, mode)
    return ret

def bgapi_connection_open(address, address_type, tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.connection.open(address, address_type, l.bt.gap.PHY_PHY_1M)
    return ret

def bgapi_gatt_write_characteristic_value(connection, characteristic, value, tester_id):
    l = bgapi_host_connection_lookup(tester_id)
    ret = l.bt.gatt.read_characteristic_value(connection, characteristic)
    return ret
