#!/usr/bin/python
import os
import select
import time
import subprocess

gdb_process = None

def __write_to_gdb(msg):
    gdb_process.stdin.write(msg.encode('utf-8'))
    gdb_process.stdin.write(b'\n')

def start_gdb(gdb_binary):
    global gdb_process
    try:
        gdb_process = subprocess.Popen([gdb_binary, '-q', '--nh', '--nx'], bufsize=0, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        __write_to_gdb(r'set prompt (gdb)\n')
        gdb_process.stdout.readline()
        return 'OK'
    except OSError:
        return 'FAIL'

def command_gdb(cmd, timeout=None):
    async_command_gdb(cmd)
    return read_async_command_output(int(timeout) if timeout else None)

def async_command_gdb(cmd):
    __write_to_gdb(cmd)

def read_async_command_output(timeout=None):
    """ timeout in seconds """
    result = ''
    current_line = ''
    poll_obj = select.poll()
    poll_obj.register(gdb_process.stdout.fileno(), select.POLLIN)

    timestamp_before = time.time()
    timestamp_timeout = timestamp_before + (int(timeout) if timeout else 0)
    while True:
        if timeout and time.time() > timestamp_timeout:
            raise Exception('[timeout occurred] current buffer is:\n{}\n{}'.format(result, current_line))
        poll_results = poll_obj.poll(1000)
        for (fd, event) in poll_results:
            if fd == gdb_process.stdout.fileno():
                c = gdb_process.stdout.read(1).decode('utf-8')

                if c == '\n':
                    if current_line.strip() == '(gdb)':
                        return result
                    else:
                        result += current_line + '\n'
                        current_line = ''
                else:
                    current_line += c

def read_async_command_error(timeout=None, throw_exception=True):
    """ timeout in seconds """
    current_error = ''
    poll_obj = select.poll()
    poll_obj.register(gdb_process.stderr, select.POLLIN)

    timestamp_before = time.time()
    timestamp_timeout = timestamp_before + (int(timeout) if timeout else 0)
    while True:
        if timeout and time.time() > timestamp_timeout:
            if throw_exception:
                raise Exception('[timeout occurred]')
            return ""
        poll_results = poll_obj.poll(1000)
        for (fd, event) in poll_results:
            if fd == gdb_process.stderr.fileno():
                c = gdb_process.stderr.read(1).decode('utf-8')

                if c == '\n':
                    return current_error + '\n'
                else:
                    current_error += c

def send_signal_to_gdb(sig):
    os.kill(gdb_process.pid, int(sig))

def stop_gdb():
    gdb_process.terminate()

