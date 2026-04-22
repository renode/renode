import asyncio
from telnetlib3 import open_connection, TelnetReader, TelnetWriter

ENCODING = "utf-8"

reader: TelnetReader
writer: TelnetWriter

def telnet_connect(port: int) -> None:
    global reader, writer

    loop = asyncio.get_event_loop()

    # Coroutines with event loop required for robot tests
    coro = open_connection('localhost', port)
    reader, writer = loop.run_until_complete(coro)  # type: ignore

def telnet_write(text: str) -> None:
    loop = asyncio.get_event_loop()
    writer.write(text)
    loop.run_until_complete(writer.drain())
    
def telnet_read_until(until_string: str, timeout: int = 15) -> str:
    loop = asyncio.get_event_loop()

    # Wrap the readuntil coroutine with wait_for to add timeout
    coro = asyncio.wait_for(reader.readuntil(until_string.encode(ENCODING)), timeout=timeout)
    data = loop.run_until_complete(coro)

    return data.decode(ENCODING)
