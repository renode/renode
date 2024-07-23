from telnetlib import Telnet

ENCODING = "utf-8"
tn = Telnet()


def telnet_connect(port: int) -> None:
    tn.open('localhost', port)


def telnet_read_until(until_string: str, timeout: int = 15) -> str:
    data = tn.read_until(until_string.encode(ENCODING), timeout)
    return data.decode(ENCODING)
