#!/usr/bin/env python3
"""Expose a Renode monitor as an MCP server over stdio.

The bridge starts Renode with its documented ``-P`` monitor TCP endpoint and
serializes requests because a monitor connection is stateful.
"""

from __future__ import annotations

import argparse
import json
import os
import pty
import re
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any, Optional

from workflow import EmbeddedProject, WorkflowError


MAX_COMMAND_LENGTH = 4096
MAX_SCRIPT_BYTES = 4 * 1024 * 1024
PROMPT = re.compile(rb"(?:^|\r?\n)\([^\r\n()]{0,128}\) ?$")
PERIPHERAL_NAME = re.compile(r"^[A-Za-z0-9_.-]{1,256}$")


class RenodeError(RuntimeError):
    """An expected failure while talking to Renode."""


def _find_prompt(data: bytes) -> Optional[int]:
    match = PROMPT.search(data)
    return match.start() if match else None


def _validate_command(command: str) -> str:
    if not isinstance(command, str) or not command.strip():
        raise RenodeError("command must be a non-empty string")
    if len(command) > MAX_COMMAND_LENGTH:
        raise RenodeError(f"command exceeds {MAX_COMMAND_LENGTH} characters")
    return command.strip()


def _validate_peripheral_name(name: str) -> str:
    if not isinstance(name, str) or not PERIPHERAL_NAME.fullmatch(name):
        raise RenodeError("peripheral must contain only letters, numbers, underscores, dots, or hyphens")
    return name


def _strip_telnet_commands(data: bytes) -> bytes:
    output = bytearray()
    index = 0
    while index < len(data):
        if data[index] != 255:
            output.append(data[index])
            index += 1
            continue
        if index + 1 >= len(data):
            break
        command = data[index + 1]
        if command == 255:
            output.append(command)
            index += 2
        elif command == 250:
            terminator = data.find(b"\xff\xf0", index + 2)
            index = len(data) if terminator == -1 else terminator + 2
        else:
            index += 3
    return bytes(output)


class RenodeSession:
    def __init__(self, executable: str, startup_script: Optional[str], timeout: float, headless: bool = True):
        self.executable = executable
        self.startup_script = startup_script
        self.timeout = timeout
        self.headless = headless
        self.process: subprocess.Popen[bytes] | None = None
        self.connection: socket.socket | None = None
        self.console_pty_master: Optional[int] = None
        self.lock = threading.Lock()

    def start(self) -> None:
        if self.process and self.process.poll() is None:
            return
        try:
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", 0))
                port = probe.getsockname()[1]
        except OSError as error:
            raise RenodeError(f"could not reserve a local Renode monitor port: {error}") from error

        command = [self.executable, "--plain", "-P", str(port)]
        if self.headless:
            command[1:1] = ["--disable-gui", "--hide-log"]
        if self.startup_script:
            script = Path(self.startup_script).expanduser().resolve()
            if not script.is_file():
                raise RenodeError(f"startup script does not exist: {script}")
            if script.stat().st_size > MAX_SCRIPT_BYTES:
                raise RenodeError("startup script is too large")
            command.append(str(script))

        slave_pty = None
        try:
            self.console_pty_master, slave_pty = pty.openpty()
            self.process = subprocess.Popen(command, stdin=slave_pty, stdout=slave_pty, stderr=subprocess.PIPE, close_fds=True)
        except OSError as error:
            if self.console_pty_master is not None:
                os.close(self.console_pty_master)
                self.console_pty_master = None
            raise RenodeError(f"could not start Renode: {error}") from error
        finally:
            if slave_pty is not None:
                os.close(slave_pty)

        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                details = self.process.stderr.read().decode(errors="replace")[-1000:] if self.process.stderr else ""
                raise RenodeError(f"Renode exited during startup: {details}")
            try:
                self.connection = socket.create_connection(("127.0.0.1", port), timeout=0.25)
                self.connection.settimeout(self.timeout)
                return
            except OSError:
                time.sleep(0.05)
        self.stop()
        raise RenodeError("timed out waiting for Renode monitor")

    def load_startup_script(self, script: str) -> None:
        resolved_script = str(Path(script).expanduser().resolve())
        if self.startup_script != resolved_script:
            self.stop()
            self.startup_script = resolved_script
        self.start()

    def stop(self) -> None:
        if self.connection:
            self.connection.close()
            self.connection = None
        if self.console_pty_master is not None:
            os.close(self.console_pty_master)
            self.console_pty_master = None
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.process = None

    def command(self, command: str) -> str:
        command = _validate_command(command)
        with self.lock:
            self.start()
            if not self.connection:
                raise RenodeError("Renode monitor is not connected")
            try:
                self.connection.sendall(command.encode() + b"\n")
                return self._read_response().strip()
            except (OSError, TimeoutError) as error:
                self.stop()
                raise RenodeError(f"Renode monitor connection failed: {error}") from error

    def _read_response(self) -> str:
        if not self.connection:
            raise RenodeError("Renode monitor is not connected")
        data = bytearray()
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            prompt_start = _find_prompt(bytes(data))
            if prompt_start is not None:
                return _strip_telnet_commands(bytes(data[:prompt_start])).decode(errors="replace")
            try:
                chunk = self.connection.recv(4096)
            except socket.timeout:
                continue
            if not chunk:
                raise RenodeError("Renode closed the monitor connection")
            data.extend(chunk)
        raise RenodeError("timed out waiting for Renode monitor response")


TOOLS = [
    {"name": "project_create", "description": "Create an embedded project from a board and requirements manifest.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}, "manifest": {"type": "object"}}, "required": ["project_dir", "manifest"], "additionalProperties": False}},
    {"name": "project_build", "description": "Build a generated project and list ELF/BIN/HEX artifacts.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}, "command": {"type": "string"}}, "required": ["project_dir"], "additionalProperties": False}},
    {"name": "project_artifacts", "description": "List generated firmware artifacts in a project build directory.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}}, "required": ["project_dir"], "additionalProperties": False}},
    {"name": "renode_start", "description": "Start Renode, optionally loading a local .resc script.", "inputSchema": {"type": "object", "properties": {"script": {"type": "string", "description": "Local Renode .resc file path."}}, "additionalProperties": False}},
    {"name": "renode_load_elf", "description": "Load an ARM ELF from a generated project into the running Renode machine.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}, "elf": {"type": "string", "description": "Project-relative ELF path when more than one exists."}}, "required": ["project_dir"], "additionalProperties": False}},
    {"name": "renode_verify_project", "description": "Load an ARM firmware ELF, start Renode, and return a structured simulation verification report.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}, "elf": {"type": "string", "description": "Project-relative ELF path when more than one exists."}}, "required": ["project_dir"], "additionalProperties": False}},
    {"name": "renode_run_project", "description": "Alias for renode_verify_project.", "inputSchema": {"type": "object", "properties": {"project_dir": {"type": "string"}, "elf": {"type": "string"}}, "required": ["project_dir"], "additionalProperties": False}},
    {"name": "renode_system_info", "description": "Return the current Renode virtual-time and emulation status.", "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "renode_open_uart_analyzer", "description": "Open Renode's native UART analyzer window for a UART peripheral.", "inputSchema": {"type": "object", "properties": {"peripheral": {"type": "string", "description": "UART peripheral name, e.g. sysbus.usart2."}}, "additionalProperties": False}},
    {"name": "renode_command", "description": "Execute one Renode monitor command and return its textual output.", "inputSchema": {"type": "object", "properties": {"command": {"type": "string", "description": "A Renode monitor command."}}, "required": ["command"], "additionalProperties": False}},
    {"name": "renode_stop", "description": "Stop the managed Renode process.", "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
]


class McpServer:
    def __init__(self, session: RenodeSession):
        self.session = session

    def handle(self, request: dict[str, Any]) -> dict[str, Any] | None:
        request_id = request.get("id")
        method = request.get("method")
        if method == "notifications/initialized":
            return None
        if method == "ping":
            return {"jsonrpc": "2.0", "id": request_id, "result": {}}
        if method == "initialize":
            return {"jsonrpc": "2.0", "id": request_id, "result": {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "renode-mcp", "version": "0.1.0"}}}
        if method == "tools/list":
            return {"jsonrpc": "2.0", "id": request_id, "result": {"tools": TOOLS}}
        if method == "tools/call":
            return self._call_tool(request_id, request.get("params") or {})
        if request_id is None:
            return None
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": f"method not found: {method}"}}

    def _call_tool(self, request_id: Any, params: dict[str, Any]) -> dict[str, Any]:
        name = params.get("name")
        arguments = params.get("arguments") or {}
        try:
            if name == "project_create":
                project = EmbeddedProject(Path(arguments["project_dir"]))
                text = json.dumps(project.create(arguments["manifest"]), indent=2)
            elif name == "project_build":
                project = EmbeddedProject(Path(arguments["project_dir"]))
                text = json.dumps(project.build(arguments.get("command")), indent=2)
            elif name == "project_artifacts":
                project = EmbeddedProject(Path(arguments["project_dir"]))
                text = json.dumps({"project": str(project.root), "artifacts": project.artifacts()}, indent=2)
            elif name == "renode_start":
                if "script" in arguments:
                    self.session.load_startup_script(arguments["script"])
                else:
                    self.session.start()
                text = "Renode is running."
            elif name == "renode_load_elf":
                project = EmbeddedProject(Path(arguments["project_dir"]))
                elf = project.firmware_elf(arguments.get("elf"))
                text = self.session.command(f"sysbus LoadELF @{elf['path']}")
            elif name in {"renode_run_project", "renode_verify_project"}:
                project = EmbeddedProject(Path(arguments["project_dir"]))
                script = project.root / "renode/board.resc"
                if not script.is_file():
                    raise WorkflowError("project has no renode/board.resc")
                elf = project.firmware_elf(arguments.get("elf"))
                self.session.load_startup_script(str(script))
                load_output = self.session.command(f"sysbus LoadELF @{elf['path']}")
                start_output = self.session.command("start")
                time_output = self.session.command("emulation GetTimeSourceInfo")
                text = json.dumps({
                    "project": str(project.root),
                    "firmware": elf,
                    "simulation": {
                        "status": "started",
                        "load_output": load_output,
                        "start_output": start_output,
                        "time_source": time_output,
                    },
                    "assertions": project.test_spec().get("assertions", []),
                }, indent=2)
            elif name == "renode_system_info":
                text = json.dumps({"time_source": self.session.command("emulation GetTimeSourceInfo")}, indent=2)
            elif name == "renode_open_uart_analyzer":
                peripheral = _validate_peripheral_name(arguments.get("peripheral", "sysbus.usart2"))
                text = self.session.command(f"showAnalyzer {peripheral}")
            elif name == "renode_command":
                text = self.session.command(arguments.get("command"))
            elif name == "renode_stop":
                self.session.stop()
                text = "Renode stopped."
            else:
                raise RenodeError(f"unknown tool: {name}")
            return {"jsonrpc": "2.0", "id": request_id, "result": {"content": [{"type": "text", "text": text}]}}
        except (RenodeError, WorkflowError, TypeError, ValueError, KeyError) as error:
            return {"jsonrpc": "2.0", "id": request_id, "result": {"isError": True, "content": [{"type": "text", "text": str(error)}]}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--renode", default=os.environ.get("RENODE_EXECUTABLE", "renode"), help="Renode executable")
    parser.add_argument("--timeout", type=float, default=10.0, help="Monitor startup/response timeout in seconds")
    parser.add_argument("--show-ui", action="store_true", help="Keep Renode's native UI visible instead of running headless")
    args = parser.parse_args()
    session = RenodeSession(args.renode, None, args.timeout, headless=not args.show_ui)
    server = McpServer(session)
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            try:
                request = json.loads(line)
                response = server.handle(request)
            except (json.JSONDecodeError, TypeError) as error:
                response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": str(error)}}
            if response is not None:
                sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
                sys.stdout.flush()
    finally:
        session.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
