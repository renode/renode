import socket
from telnetlib import Telnet

ENCODING = "utf-8"
tn = Telnet()


def find_free_port() -> int:
    # Return open port number
    s = socket.socket()
    s.bind(('localhost', 0))
    port = s.getsockname()[1]
    s.close()
    return port


def telnet_connect(port: int) -> None:
    tn.open('localhost', port)


def telnet_read_until(until_string: str, timeout: int = 15) -> str:
    data = tn.read_until(until_string.encode(ENCODING), timeout)
    return data.decode(ENCODING)
