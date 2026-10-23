import unittest
import json
import tempfile
from pathlib import Path
from unittest import mock

from server import McpServer, RenodeError, RenodeSession, _find_prompt, _strip_telnet_commands, _validate_command, _validate_peripheral_name
from workflow import EmbeddedProject, WorkflowError


class ServerHelpersTest(unittest.TestCase):
    def test_find_prompt_at_end(self):
        self.assertEqual(_find_prompt(b"ok\r\n(monitor) "), 2)

    def test_find_prompt_accepts_machine_name(self):
        self.assertIsNotNone(_find_prompt(b"output\n(my_machine) "))

    def test_find_prompt_rejects_non_terminal_prompt(self):
        self.assertIsNone(_find_prompt(b"(monitor) output"))

    def test_validate_command(self):
        self.assertEqual(_validate_command("  version  "), "version")
        with self.assertRaises(Exception):
            _validate_command(" ")

    def test_validate_peripheral_name(self):
        self.assertEqual(_validate_peripheral_name("sysbus.usart2"), "sysbus.usart2")
        with self.assertRaises(RenodeError):
            _validate_peripheral_name("sysbus.usart2; quit")

    def test_strip_telnet_commands(self):
        self.assertEqual(_strip_telnet_commands(b"\xff\xfd\x1f\xff\xfb\x01Renode"), b"Renode")

    def test_session_reports_unavailable_loopback_port(self):
        with mock.patch("server.socket.socket", side_effect=OSError("blocked")):
            with self.assertRaisesRegex(RenodeError, "could not reserve"):
                RenodeSession("renode", None, 1).start()

    def test_session_reports_unavailable_pseudo_terminal(self):
        with mock.patch("server.socket.socket") as socket_factory, mock.patch("server.pty.openpty", side_effect=OSError("blocked")):
            socket_factory.return_value.__enter__.return_value.getsockname.return_value = ("127.0.0.1", 12345)
            with self.assertRaisesRegex(RenodeError, "could not start Renode"):
                RenodeSession("renode", None, 1).start()


class WorkflowTest(unittest.TestCase):
    def test_create_project_and_list_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            project = EmbeddedProject(Path(directory) / "breathing")
            result = project.create({
                "name": "led_breathing",
                "board": {"mcu": "STM32F401RE", "datasheet": "/missing/datasheet.pdf"},
                "requirements": {"led_gpio": "PA5", "breath_period_ms": 2000},
            })
            self.assertIn("src/main.c", result["files"])
            self.assertFalse(result["datasheet"]["exists"])
            self.assertEqual(project.test_spec()["name"], "led_breathing")
            self.assertEqual(project.artifacts(), [])

    def test_firmware_elf_requires_arm_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self._create_project(Path(directory))
            elf = project.root / "build/firmware.elf"
            elf.parent.mkdir()
            elf.write_bytes(b"\x7fELF\x01\x01" + b"\x00" * 12 + b"\x28\x00")
            self.assertEqual(project.firmware_elf()["machine_name"], "ARM")
            elf.write_bytes(b"\x7fELF\x02\x01" + b"\x00" * 12 + b"\x3e\x00")
            with self.assertRaises(WorkflowError):
                project.firmware_elf()

    def test_manifest_requires_led_gpio(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(WorkflowError):
                EmbeddedProject(Path(directory)).create({"name": "bad", "board": {"mcu": "STM32F4"}})

    @staticmethod
    def _create_project(root):
        project = EmbeddedProject(root / "breathing")
        project.create({
            "name": "led_breathing",
            "board": {"mcu": "STM32F401RE"},
            "requirements": {"led_gpio": "PA5"},
        })
        return project


class McpVerificationTest(unittest.TestCase):
    def test_verify_project_loads_arm_elf_and_starts_emulation(self):
        with tempfile.TemporaryDirectory() as directory:
            project = WorkflowTest._create_project(Path(directory))
            elf = project.root / "build/firmware.elf"
            elf.parent.mkdir()
            elf.write_bytes(b"\x7fELF\x01\x01" + b"\x00" * 12 + b"\x28\x00")
            session = FakeSession()
            response = McpServer(session).handle({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {"name": "renode_verify_project", "arguments": {"project_dir": str(project.root)}},
            })
            report = json.loads(response["result"]["content"][0]["text"])
            self.assertEqual(report["firmware"]["machine_name"], "ARM")
            self.assertEqual(session.commands, [f"sysbus LoadELF @{elf}", "start", "emulation GetTimeSourceInfo"])

    def test_system_info_and_uart_analyzer(self):
        session = FakeSession()
        server = McpServer(session)
        info_response = server.handle({"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "renode_system_info", "arguments": {}}})
        analyzer_response = server.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "renode_open_uart_analyzer", "arguments": {"peripheral": "sysbus.usart2"}}})
        self.assertEqual(json.loads(info_response["result"]["content"][0]["text"])["time_source"], "ok")
        self.assertEqual(analyzer_response["result"]["content"][0]["text"], "ok")
        self.assertEqual(session.commands, ["emulation GetTimeSourceInfo", "showAnalyzer sysbus.usart2"])


class FakeSession:
    def __init__(self):
        self.commands = []
        self.startup_script = None

    def load_startup_script(self, script):
        self.startup_script = script

    def command(self, command):
        self.commands.append(command)
        return "ok"

    def stop(self):
        return None


if __name__ == "__main__":
    unittest.main()
