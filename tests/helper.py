import subprocess
import fnmatch
import os
import sys
import psutil
import socket

def network_interface_should_exist(name):
    if name not in psutil.net_if_addrs():
        raise Exception('Network interface {} not found.'.format(name))

def network_interface_should_be_up(name):
    network_interface_should_exist(name)
    if sys.platform == "linux": # psutil marks tap interface as down, erroneously
        proc = subprocess.Popen(['ip', 'addr', 'show', name, 'up'], stdout=subprocess.PIPE)
        (output, err) = proc.communicate()
        exit_code = proc.wait()
        if exit_code != 0 or len(output) == 0:
            raise Exception('Network interface {} is not up.'.format(name))
    else:
        if not (name in psutil.net_if_stats() and psutil.net_if_stats()[name].isup):
            raise Exception('Network interface {} is not up.'.format(name))

def network_interface_should_have_address(name, address):
    network_interface_should_exist(name)
    if not (sys.platform == "win32" or sys.platform == "cygwin"):
        # On Windows, the status of TAP interface depends on the
        # signals sent to the device file using the DeviceIoControl
        # function from Win32 API. For this reason it is the Renode
        # that sets the up/down status instead - and as such for the
        # automated testing this check is skipped on Windows.
        network_interface_should_be_up(name)
    ifaddresses = psutil.net_if_addrs()[name]
    addresses = []
    for addr in ifaddresses:
        if addr.family == socket.AF_INET:
            addresses.append(addr.address)
    if address not in addresses:
        raise Exception('Network interface {0} does not have address {1}.'.format(name, address))

def list_files_in_directory_recursively(directory_name, pattern, excludes=None):
    files = []
    for root, dirnames, filenames in os.walk(directory_name, topdown=True):
        if excludes and os.path.basename(root) in excludes:
            # this is an `os.walk` trick: when using `topdown=True`
            # you can modify `dirnames` in place to tell `os.walk`
            # which folders to visit; in this case - visit nothing
            dirnames[:] = []
            continue

        for filename in fnmatch.filter(filenames, pattern):
            files.append(os.path.join(root, filename))
    return files
