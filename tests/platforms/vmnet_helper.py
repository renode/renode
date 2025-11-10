import sys
import subprocess
import ipaddress
import time
from pathlib import Path

class ValidationError(Exception):
    pass

VMNET_HELPER_BINARY = "/opt/vmnet-helper/bin/vmnet-helper"

vmnet_helper_pid = None

def preconfigure_vmnet_helper(start_ipv4, end_ipv4, mask, socket_path):
    if sys.platform != "darwin":
        return
    
    try:
        ipaddress.IPv4Address(start_ipv4)
        ipaddress.IPv4Address(end_ipv4)
        ipaddress.IPv4Address(mask)
    except ValueError as e:
        raise ValidationError(f"Incorrect ipv4 address: {e}")

    try:
        ipaddress.ip_network(f"{start_ipv4}/{mask}", strict=False)
    except ValueError as e:
        raise ValidationError(f"Incorrect ipv4 mask: {e}")

    p = Path(socket_path)
    if not p.parent.exists():
        raise ValueError(f"Invalid Path: {p}")

    proc = subprocess.Popen(
        [
            "sudo",
            VMNET_HELPER_BINARY,
            "-v",
            f"--socket={socket_path}",
            "--operation-mode=host",
            f"--start-address={start_ipv4}",
            f"--end-address={end_ipv4}",
            f"--subnet-mask={mask}",
        ]
    )
    time.sleep(1)
    exit_code = proc.poll()
    if exit_code is not None:
        raise Exception(f"Process has Exited with code: {exit_code}")
    
    global vmnet_helper_pid
    vmnet_helper_pid = proc.pid

def kill_vmnet_helper():
    global vmnet_helper_pid
    if vmnet_helper_pid is None:
        return
    
    try:
        vmnet_helper_pid = int(vmnet_helper_pid)
    except ValueError as e:
        raise ValidationError(f"Incorrect PID value, an integer was expected: {e}")

    # vmnet-helper drops its priviledges - sudo is not needed
    subprocess.Popen(["kill", f"{vmnet_helper_pid}"]).wait()
    vmnet_helper_pid = None
