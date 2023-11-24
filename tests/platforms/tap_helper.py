import sys
import subprocess

def preconfigure_macos(iface, addr, mask):
    if sys.platform == "darwin":
        proc = subprocess.Popen(["sudo", "ifconfig", iface, addr, mask], stdout=subprocess.PIPE)
        exit_code = proc.wait()
        if exit_code != 0:
            raise Exception("Quark Helper could not configure interface {}".format(iface))