import requests
import sys
import subprocess

def get_request(url):
    # we remove headers to make request as small as possible (at most 128 bytes) to be handled correctly by Zephyr
    return requests.get(url, headers={'Connection' : None, 'Accept-Encoding': None, 'Accept': None, 'User-Agent': None})

def preconfigure_macos(iface, addr, mask):
    if sys.platform == "darwin":
        proc = subprocess.Popen(["sudo", "ifconfig", iface, addr, mask], stdout=subprocess.PIPE)
        exit_code = proc.wait()
        if exit_code != 0:
            raise Exception("Quark Helper could not configure interface {}".format(iface))