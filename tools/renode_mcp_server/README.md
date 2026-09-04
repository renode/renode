## Control Renode from an MCP-compatible AI agent

This directory contains a local stdio Model Context Protocol (MCP) server
that allows an AI agent to control one Renode session. The server starts
Renode with its monitor enabled, translates MCP tool calls into monitor
commands, and returns the textual result to the agent.

The server works with any agent host that supports **stdio MCP servers** and
tool calls. Codex is only one possible host; it is not required. A Traditional
Chinese guide is available in [README.zh-TW.md](README.zh-TW.md).

> **Status:** experimental and local-only. The server controls Renode
> simulation; it does not connect to, flash, or replace physical hardware.

### Requirements

* Python 3.9 or newer. No third-party Python packages are required.
* A local Renode executable. Verify it with `renode --version` or
  `/absolute/path/to/renode --version`.
* A .NET runtime only if the selected Renode wrapper needs it. For a source
  build, pass `DOTNET_ROOT` and add its directory to `PATH`.
* An agent host capable of starting a local stdio MCP process, calling tools,
  using loopback TCP, and reading/writing the firmware project directory.

The server listens for MCP JSON-RPC messages on standard input/output. It
starts Renode's monitor on a random `127.0.0.1` port; no TCP MCP endpoint is
exposed. The agent host must not add protocol logs to the server's standard
output.

### Usage

```
usage: server.py [-h] [--renode RENODE] [--timeout TIMEOUT] [--show-ui]

Expose a Renode monitor as an MCP server over stdio.

optional arguments:
  -h, --help         show this help message and exit
  --renode RENODE    Renode executable (default: renode from PATH)
  --timeout TIMEOUT  Monitor startup/response timeout in seconds (default: 10)
  --show-ui          Keep Renode's native UI visible instead of running headless
```

Run the server only through an MCP host. For diagnostics, `--help` is safe to
run directly; a normal direct invocation waits for MCP JSON-RPC input.

### Configure your AI agent

Register this executable as a stdio MCP server in the configuration for your
agent host. The configuration syntax varies by host, but the process contract
is always the same:

```text
command: /usr/bin/python3
args:
  - /absolute/path/to/renode/tools/renode_mcp_server/server.py
  - --renode
  - /absolute/path/to/renode/renode
environment (source build only):
  DOTNET_ROOT: /absolute/path/to/dotnet
  PATH: /absolute/path/to/dotnet:/usr/local/bin:/usr/bin:/bin
```

With a packaged Renode installation, omit `DOTNET_ROOT` and set `PATH` only
when it is needed to locate `renode`.

For hosts using a JSON-style MCP configuration, the equivalent minimal setup
looks like this. Add the `env` object when the Renode executable requires it.

```json
{
  "mcpServers": {
    "renode": {
      "command": "/usr/bin/python3",
      "args": [
        "/absolute/path/to/renode/tools/renode_mcp_server/server.py",
        "--renode",
        "/absolute/path/to/renode/renode"
      ]
    }
  }
}
```

After changing the host configuration, start a new agent session. The agent
should discover the `renode` tools with `tools/list`, then call them using the
standard MCP `tools/call` method.

#### Codex CLI example

Codex users can register the same process with:

```sh
codex mcp add renode \
  --env DOTNET_ROOT="/absolute/path/to/dotnet" \
  --env PATH="/absolute/path/to/dotnet:/usr/local/bin:/usr/bin:/bin" \
  -- /usr/bin/python3 \
  "/absolute/path/to/renode/tools/renode_mcp_server/server.py" \
  --renode "/absolute/path/to/renode/renode"
```

Confirm it with `codex mcp get renode --json`. The
`codex.renode.toml.example` file is an equivalent configuration template.

### Tools

| Tool | Required input | Result |
| --- | --- | --- |
| `renode_start` | Optional `script` path | Starts Renode and optionally loads a `.resc` script. |
| `renode_stop` | None | Stops the Renode child process. |
| `renode_command` | `command` | Runs one Renode monitor command. |
| `renode_system_info` | None | Returns virtual time and emulator state. |
| `renode_open_uart_analyzer` | Optional `peripheral` | Opens a native UART analyzer; requires `--show-ui`. |
| `project_create` | `project_dir`, `manifest` | Creates a firmware project scaffold and Renode scenario. |
| `project_build` | `project_dir` | Builds a generated project and finds artifacts. |
| `project_artifacts` | `project_dir` | Lists ELF/BIN/HEX/MAP artifacts. |
| `renode_load_elf` | `project_dir` | Loads the project's ARM ELF into the current machine. |
| `renode_verify_project` | `project_dir` | Loads an ARM ELF, starts emulation, and returns a report. |
| `renode_run_project` | `project_dir` | Alias for `renode_verify_project`. |

### Examples

#### Check that an agent can control Renode

In a new session, tell your agent:

```text
Use the renode MCP. Call renode_start, renode_system_info,
renode_command with command "version", and renode_stop in that order.
Report the result of every tool call.
```

Success means the agent receives `Renode is running.`, time-source output
containing `Elapsed Virtual Time` and `State`, Renode version information, and
`Renode stopped.`.

#### Run an existing board simulation

Provide the agent with a board-specific `.resc` script, its referenced `.repl`
platform description, and an ARM ELF. Then ask:

```text
Use renode_start with /path/to/board.resc. Load the ARM ELF from the project
with renode_load_elf, start the emulation with renode_command, then call
renode_system_info. Report the virtual time, state, and monitor output.
```

Use `renode_stop` after the inspection. The `.resc` script must create the
machine and define the peripherals that the firmware expects.

#### Create a project scaffold

Ask the agent:

```text
Use project_create to create /tmp/led-breathing for an STM32F401RE with an
active-high LED on PA5, a 2000 ms breathing period, and sysbus.usart2.
Call project_build and project_artifacts. After an ARM ELF is available,
call renode_verify_project and report the result.
```

The `project_create` manifest accepts this shape:

```json
{
  "name": "led_breathing",
  "board": {
    "mcu": "STM32F401RE",
    "datasheet": "/workspace/docs/STM32F401RE.pdf",
    "renode_platform": "platforms/cpus/stm32f4.repl",
    "elf_machine": 40
  },
  "requirements": {
    "led_gpio": "PA5",
    "led_active_high": true,
    "breath_period_ms": 2000,
    "uart": "sysbus.usart2"
  }
}
```

#### Open a UART analyzer for a human observer

Add `--show-ui` to the server arguments and ensure the host has Renode's
native GTK/desktop dependencies. After loading a scenario that defines
`sysbus.usart2`, ask the agent to call `renode_open_uart_analyzer` with
`peripheral: "sysbus.usart2"`.

The analyzer window is for a human observer. This server does not yet capture
analyzer pixels or stream UART text back as a dedicated MCP tool.

### Limitations

* `project_create` creates a toolchain-neutral CMake skeleton. It does not
  generate vendor HAL/CMSIS code, startup code, linker scripts, or a
  board-accurate peripheral model from a datasheet.
* The `datasheet` manifest field is recorded and its local-file existence is
  reported; the server does not parse the datasheet.
* A native `project_build` produces a host ELF. STM32 simulation needs an
  `arm-none-eabi` toolchain and an `EM_ARM` ELF.
* `renode_verify_project` checks ELF architecture, loads firmware, starts
  emulation, and returns generated assertions. It does **not** execute those
  assertions or prove GPIO/PWM behaviour.
* A board-specific `.repl`/`.resc` is required. Renode simulation is not a
  substitute for final hardware-in-the-loop testing or flashing a board.

### Test

Run from the Renode repository root:

```sh
python3 -m unittest discover -s tools/renode_mcp_server -p 'test_*.py'
```
