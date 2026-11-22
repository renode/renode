# Host processes talking to emulated NCPs over a PTY, used as a Robot keyword library (Linux only)
import os
import pty
import queue
import re
import subprocess
import threading

from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn

# Real seconds to wait for host output between checks of the emulated time
STEP = 0.05
# Zigbee hosts don't flush their output, a newline every emulated second makes them do it
FLUSH_PERIOD = 1.0

_processes = {}


def launch_host_process(name, binary, *args, renode_port=None, preload=None):
    env = None
    if renode_port is not None or preload is not None:
        env = os.environ.copy()
        if renode_port is not None:
            env["RENODE_PORT"] = str(renode_port)
        if preload is not None:
            env["LD_PRELOAD"] = ":".join(filter(None, (env.get("LD_PRELOAD"), preload)))
    master, slave = pty.openpty()
    process = subprocess.Popen([binary, *args], stdin=slave, stdout=slave, stderr=slave, close_fds=True, env=env)
    os.close(slave)
    lines = queue.Queue()
    threading.Thread(target=_read_lines, args=(master, lines), daemon=True).start()
    _processes[name] = (process, master, lines)


def write_line_to_host(name, line):
    if line:
        logger.info(f"[{name}] < {line}")
    os.write(_processes[name][1], (line + "\n").encode())


def wait_for_host_line(name, pattern, timeout=10):
    process, _, lines = _processes[name]
    regex = re.compile(pattern)
    start = _virtual_time()
    next_flush = start + FLUSH_PERIOD
    _monitor("start")
    try:
        while (now := _virtual_time()) < start + float(timeout):
            if now >= next_flush:
                write_line_to_host(name, "")
                next_flush = now + FLUSH_PERIOD
            try:
                line = lines.get(timeout=STEP)
            except queue.Empty:
                if process.poll() is not None:
                    raise AssertionError(f"Host process {name} exited with {process.returncode}")
                continue
            logger.info(f"[{name} +{now - start:.2f} s] {line}")
            if regex.search(line):
                return line
        raise AssertionError(f"Timed out waiting for '{pattern}' from host process {name} after {timeout} s")
    finally:
        _monitor("pause")


def _monitor(command):
    return BuiltIn().run_keyword("Execute Command", command)


def _virtual_time():
    info = _monitor("emulation GetTimeSourceInfo")
    h, m, s = re.search(r"Elapsed Virtual Time: (\d+):(\d+):([\d.]+)", info).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


def terminate_host_processes():
    for process, master, _ in _processes.values():
        process.kill()
        process.wait()
        os.close(master)
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
