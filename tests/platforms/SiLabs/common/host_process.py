# Host processes talking to emulated NCPs over a PTY, used as a Robot keyword library (Linux only)
import os
import pty
import queue
import re
import stat
import subprocess
import tempfile
import threading
import urllib.request

from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn

# Emulated seconds advanced between checks for new host output
STEP = 0.05
# Zigbee hosts don't flush their output, a newline every emulated second makes them do it
FLUSH_PERIOD = 1.0

_processes = {}


def launch_host_process(name, binary, *args):
    downloaded = None
    if binary.startswith(("http://", "https://")):
        fd, downloaded = tempfile.mkstemp(prefix=f"renode_{name}_")
        os.close(fd)
        urllib.request.urlretrieve(binary, downloaded)
        os.chmod(downloaded, os.stat(downloaded).st_mode | stat.S_IEXEC)
        binary = downloaded
    master, slave = pty.openpty()
    process = subprocess.Popen([binary, *args], stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    lines = queue.Queue()
    threading.Thread(target=_read_lines, args=(master, lines), daemon=True).start()
    _processes[name] = (process, master, lines, downloaded)


def write_line_to_host(name, line):
    os.write(_processes[name][1], (line + "\n").encode())


def wait_for_host_line(name, pattern, timeout=10):
    process, _, lines, _ = _processes[name]
    regex = re.compile(pattern)
    elapsed = since_flush = 0.0
    while elapsed < float(timeout):
        try:
            line = lines.get(timeout=STEP)
        except queue.Empty:
            if process.poll() is not None:
                raise AssertionError(f"Host process {name} exited with {process.returncode}")
            BuiltIn().run_keyword("Execute Command", f'emulation RunFor "{STEP}"')
            elapsed += STEP
            since_flush += STEP
            if since_flush >= FLUSH_PERIOD:
                write_line_to_host(name, "")
                since_flush = 0.0
            continue
        logger.info(f"[{name}] {line}")
        if regex.search(line):
            return line
    raise AssertionError(f"Timed out waiting for '{pattern}' from host process {name} after {timeout} s")


def terminate_host_processes():
    for process, master, _, downloaded in _processes.values():
        process.kill()
        process.wait()
        os.close(master)
        if downloaded:
            os.remove(downloaded)
    _processes.clear()


def _read_lines(fd, lines):
    pending = b""
    while True:
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        pending += chunk
        *complete, pending = pending.split(b"\n")
        for line in complete:
            lines.put(line.decode(errors="replace").rstrip("\r"))
    if pending:
        lines.put(pending.decode(errors="replace"))
