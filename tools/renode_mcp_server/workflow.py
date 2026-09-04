"""Project and verification workflow used by the Renode MCP server."""

from __future__ import annotations

import json
import os
import shlex
import struct
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional


class WorkflowError(RuntimeError):
    """An invalid project request or workflow failure."""


ELF_MACHINE_NAMES = {
    40: "ARM",
    183: "AArch64",
}


def _safe_path(path: str, root: Path) -> Path:
    candidate = Path(path).expanduser()
    if not candidate.is_absolute():
        candidate = root / candidate
    candidate = candidate.resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as error:
        raise WorkflowError("path must remain inside the project directory") from error
    return candidate


class ProjectManifest:
    def __init__(self, data: Dict[str, Any]):
        board = data.get("board") or {}
        requirements = data.get("requirements") or {}
        self.name = self._required_string(data, "name", "project")
        self.board = board
        self.requirements = requirements
        self.mcu = self._required_string(board, "mcu", "board.mcu")
        self.datasheet = board.get("datasheet")
        if self.datasheet is not None and not isinstance(self.datasheet, str):
            raise WorkflowError("board.datasheet must be a local file path")
        self.cpu_platform = board.get("renode_platform", "platforms/cpus/stm32f4.repl")
        self.elf_machine = int(board.get("elf_machine", 40))
        self.led_gpio = self._required_string(requirements, "led_gpio", "requirements.led_gpio")
        self.led_active_high = bool(requirements.get("led_active_high", True))
        self.breath_period_ms = int(requirements.get("breath_period_ms", 2000))
        self.uart = requirements.get("uart", "sysbus.usart2")
        if self.breath_period_ms < 100:
            raise WorkflowError("requirements.breath_period_ms must be at least 100")

    @staticmethod
    def _required_string(data: Dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            raise WorkflowError(f"{label} must be a non-empty string")
        return value.strip()

    @classmethod
    def load(cls, path: Path) -> "ProjectManifest":
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise WorkflowError(f"could not read manifest: {error}") from error
        if not isinstance(data, dict):
            raise WorkflowError("manifest must contain a JSON object")
        return cls(data)


class EmbeddedProject:
    def __init__(self, root: Path):
        self.root = root.resolve()

    @property
    def manifest_path(self) -> Path:
        return self.root / "manifest.json"

    def create(self, manifest_data: Dict[str, Any]) -> Dict[str, Any]:
        manifest = ProjectManifest(manifest_data)
        self.root.mkdir(parents=True, exist_ok=True)
        files = {
            "manifest.json": json.dumps(manifest_data, indent=2) + "\n",
            "README.md": self._readme(manifest),
            "CMakeLists.txt": self._cmake(manifest),
            "src/main.c": self._main_c(manifest),
            "include/app_config.h": self._config_h(manifest),
            "renode/board.resc": self._resc(manifest),
            "tests/led_breathing.json": self._test_spec(manifest),
        }
        for relative, content in files.items():
            destination = _safe_path(relative, self.root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content)
        result = {"project": str(self.root), "files": sorted(files), "manifest": manifest_data}
        if manifest.datasheet:
            datasheet = Path(manifest.datasheet).expanduser().resolve()
            result["datasheet"] = {"path": str(datasheet), "exists": datasheet.is_file()}
        return result

    def build(self, command: Optional[str] = None, timeout: int = 120) -> Dict[str, Any]:
        if not self.manifest_path.is_file():
            raise WorkflowError("project has no manifest.json")
        build_command = command or os.environ.get("RENODE_MCP_BUILD_COMMAND", "cmake -S . -B build && cmake --build build")
        commands = [part.strip() for part in build_command.split("&&")]
        if not commands or any(not part for part in commands):
            raise WorkflowError("build command must contain one or more commands separated by &&")
        stdout = []
        stderr = []
        returncode = 0
        try:
            for command_part in commands:
                argv = shlex.split(command_part)
                if not argv or any(token in {";", "&&", "||", "|", ">", "<"} for token in argv):
                    raise WorkflowError("build command contains an unsupported shell operator")
                result = subprocess.run(argv, cwd=self.root, capture_output=True, text=True, timeout=timeout, check=False)
                stdout.append(result.stdout)
                stderr.append(result.stderr)
                returncode = result.returncode
                if returncode != 0:
                    break
        except (OSError, subprocess.TimeoutExpired) as error:
            raise WorkflowError(f"build failed to start or timed out: {error}") from error
        return {"success": returncode == 0, "returncode": returncode, "stdout": "".join(stdout)[-12000:], "stderr": "".join(stderr)[-12000:], "artifacts": self.artifacts()}

    def artifacts(self) -> List[str]:
        candidates = []
        for path in self.root.glob("build/**/*"):
            if path.is_file() and "CMakeFiles" not in path.parts and path.suffix.lower() in {".elf", ".bin", ".hex", ".map"}:
                candidates.append(str(path.relative_to(self.root)))
        return sorted(candidates)

    def firmware_elf(self, requested_elf: Optional[str] = None) -> Dict[str, Any]:
        if requested_elf:
            elf = _safe_path(requested_elf, self.root)
            if not elf.is_file():
                raise WorkflowError(f"ELF does not exist: {elf}")
        else:
            candidates = [self.root / artifact for artifact in self.artifacts() if artifact.lower().endswith(".elf")]
            if not candidates:
                raise WorkflowError("no ELF artifact found; build the project with an embedded toolchain first")
            if len(candidates) != 1:
                raise WorkflowError("multiple ELF artifacts found; pass elf explicitly")
            elf = candidates[0]

        details = inspect_elf(elf)
        manifest = ProjectManifest.load(self.manifest_path)
        if details["machine"] != manifest.elf_machine:
            expected = ELF_MACHINE_NAMES.get(manifest.elf_machine, str(manifest.elf_machine))
            actual = details["machine_name"]
            raise WorkflowError(f"ELF architecture is {actual}; expected {expected} for {manifest.mcu}")
        details["path"] = str(elf)
        details["relative_path"] = str(elf.relative_to(self.root))
        return details

    def test_spec(self) -> Dict[str, Any]:
        path = self.root / "tests/led_breathing.json"
        if not path.is_file():
            raise WorkflowError("project has no led breathing test specification")
        return json.loads(path.read_text())

    @staticmethod
    def _cmake(manifest: ProjectManifest) -> str:
        return f'''cmake_minimum_required(VERSION 3.15)
project({manifest.name} C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_executable(${{PROJECT_NAME}} src/main.c)
target_include_directories(${{PROJECT_NAME}} PRIVATE include)
set_target_properties(${{PROJECT_NAME}} PROPERTIES SUFFIX ".elf")
message(STATUS "Cross-compile this template with an STM32 HAL/CMSIS toolchain")
'''

    @staticmethod
    def _config_h(manifest: ProjectManifest) -> str:
        gpio = manifest.led_gpio.replace("-", "_")
        return f'''#pragma once

#define APP_MCU "{manifest.mcu}"
#define APP_LED_GPIO "{gpio}"
#define APP_LED_ACTIVE_HIGH {1 if manifest.led_active_high else 0}
#define APP_BREATH_PERIOD_MS {manifest.breath_period_ms}
'''

    @staticmethod
    def _main_c(manifest: ProjectManifest) -> str:
        return '''#include "app_config.h"
#include <stdint.h>

static void board_init(void);
static void pwm_set_duty(uint32_t duty_percent);
static void delay_ms(uint32_t milliseconds);

int main(void) {
    board_init();
    for (;;) {
        for (uint32_t duty = 0; duty <= 100; ++duty) {
            pwm_set_duty(duty);
            delay_ms(APP_BREATH_PERIOD_MS / 200);
        }
        for (uint32_t duty = 100; duty > 0; --duty) {
            pwm_set_duty(duty);
            delay_ms(APP_BREATH_PERIOD_MS / 200);
        }
    }
}

static void board_init(void) {
}

static void pwm_set_duty(uint32_t duty_percent) {
    (void)duty_percent;
}

static void delay_ms(uint32_t milliseconds) {
    (void)milliseconds;
}
'''

    @staticmethod
    def _resc(manifest: ProjectManifest) -> str:
        return f'''mach create
machine LoadPlatformDescription @{manifest.cpu_platform}
showAnalyzer {manifest.uart}
'''

    @staticmethod
    def _test_spec(manifest: ProjectManifest) -> str:
        return json.dumps({"name": "led_breathing", "duration_ms": manifest.breath_period_ms * 2, "assertions": [{"gpio": manifest.led_gpio, "minimum_transitions": 10}, {"pwm_period_ms": manifest.breath_period_ms, "tolerance_percent": 5}]}, indent=2) + "\n"

    @staticmethod
    def _readme(manifest: ProjectManifest) -> str:
        return f'''# {manifest.name}

Generated embedded project for `{manifest.mcu}`.

- LED GPIO: `{manifest.led_gpio}`
- Breathing period: `{manifest.breath_period_ms} ms`
- Renode platform: `{manifest.cpu_platform}`

The source is a portable application skeleton. Add the board vendor HAL/CMSIS
startup, linker script, and cross compiler configuration before a production
flash. The Renode scenario is in `renode/board.resc` and the verification
contract is in `tests/led_breathing.json`.
'''


def inspect_elf(path: Path) -> Dict[str, Any]:
    try:
        header = path.read_bytes()[:20]
    except OSError as error:
        raise WorkflowError(f"could not read ELF: {error}") from error
    if len(header) < 20 or header[:4] != b"\x7fELF":
        raise WorkflowError(f"not an ELF file: {path}")
    data_encoding = header[5]
    if data_encoding == 1:
        byte_order = "<"
    elif data_encoding == 2:
        byte_order = ">"
    else:
        raise WorkflowError("ELF has an unsupported byte order")
    machine = struct.unpack(f"{byte_order}H", header[18:20])[0]
    return {
        "class": 32 if header[4] == 1 else 64 if header[4] == 2 else "unknown",
        "machine": machine,
        "machine_name": ELF_MACHINE_NAMES.get(machine, f"machine-{machine}"),
    }
