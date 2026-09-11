# Renode MCP Server：通用 MCP Client 使用指南

這個 MCP server 透過 stdio 接收 AI agent 的工具呼叫，並在本機啟動 Renode；它只會將 Renode monitor 綁定到 `127.0.0.1`，不會暴露網路服務。

> **目前狀態：** 這是實驗性的本機 MCP bridge。它控制 Renode 模擬器，不會連接、燒錄或取代實體開發板。

## 使用前需要什麼？

任何支援 **stdio MCP** 與 tool call 的 AI agent host 都可以使用這個 server；Codex Desktop/CLI 只是其中一個設定範例。執行 `codex mcp get renode --json` **之前不需要啟動 Renode**，但這個指令只適用於檢查 Codex 是否已註冊此 MCP server。

每位使用者需要：

1. 安裝支援 stdio MCP server 的 AI agent host，且它可執行本機 child process、使用 loopback TCP，並可讀寫 firmware project 目錄。
2. 安裝 Python 3，且 `python3 --version` 可執行。
3. 安裝或編譯 Renode，並確認 `renode --version` 可執行。
4. 若使用此 repository 編譯的 `./renode` wrapper，還需要 .NET SDK，並在 MCP 環境中設定 `DOTNET_ROOT` 與 `PATH`。

> 安裝好的 Renode 發行版本通常可直接使用；只有從原始碼執行 Renode 時才需要自行提供 .NET runtime。

## 1. 取得程式碼與 Renode

```sh
git clone --recurse-submodules https://github.com/renode/renode.git
cd renode
```

依 Renode 的官方安裝方式安裝發行版，或依專案建置文件完成原始碼建置。完成後記下下列三個**絕對路徑**：

- `RENODE_ROOT`：Renode repository 根目錄。
- `RENODE_EXECUTABLE`：Renode 執行檔；原始碼建置通常是 `$RENODE_ROOT/renode`。
- `DOTNET_ROOT`：只有原始碼建置需要的 .NET runtime 目錄。

確認：

```sh
"$RENODE_EXECUTABLE" --version
python3 --version
codex --version
```

## 2. 連接任何 stdio MCP Host

在你的 agent host 中設定下列 command、args 與 environment，並將大寫 placeholder 換成 host 機器上的絕對路徑：

```text
command: /usr/bin/python3
args:
  - /ABSOLUTE/PATH/TO/renode/tools/renode_mcp_server/server.py
  - --renode
  - /ABSOLUTE/PATH/TO/renode/renode
environment（僅 source build 需要）:
  DOTNET_ROOT: /ABSOLUTE/PATH/TO/dotnet
  PATH: /ABSOLUTE/PATH/TO/dotnet:/usr/local/bin:/usr/bin:/bin
```

各 agent host 的設定檔格式不同，但都必須以 stdio 執行上述命令。此 server 使用換行分隔的 JSON-RPC，**不需要也不應改成 HTTP 或網路 MCP endpoint**。修改設定後，請開啟新的 agent session。

若使用安裝版 Renode 而非原始碼建置，移除 `DOTNET_ROOT`，並將 `PATH` 設為包含 `renode` 的目錄即可。

### Codex CLI 範例

建議先以 headless 模式測試，這不依賴原生 GUI。以下範例請以你的絕對路徑取代大寫 placeholder：

```sh
codex mcp add renode \
  --env DOTNET_ROOT="/ABSOLUTE/PATH/TO/dotnet" \
  --env PATH="/ABSOLUTE/PATH/TO/dotnet:/usr/local/bin:/usr/bin:/bin" \
  -- /usr/bin/python3 \
  "/ABSOLUTE/PATH/TO/renode/tools/renode_mcp_server/server.py" \
  --renode "/ABSOLUTE/PATH/TO/renode/renode"
```

確認 Codex 註冊成功：

```sh
codex mcp get renode --json
```

預期輸出包含：

```json
{"name":"renode","enabled":true}
```

開啟新的 Codex task 後，agent 才會使用更新後的 MCP 設定。要刪除 Codex 設定可執行：

```sh
codex mcp remove renode
```

## 3. 最小 smoke test

在新的 agent session 貼上：

```text
請使用 renode MCP，依序呼叫 renode_start、renode_system_info、
renode_command（command 為 version）與 renode_stop。請列出每個工具的回傳結果。
```

成功條件：

- `renode_start` 回傳 `Renode is running.`
- `renode_system_info` 包含 `Elapsed Virtual Time` 與 `State`。
- `renode_command` 回傳 Renode 版本資訊。
- `renode_stop` 回傳 `Renode stopped.`

## 4. 嵌入式專案工作流程測試

請 agent 產生 LED 呼吸燈專案：

```text
請使用 renode MCP，在 /tmp/led-breathing 建立 STM32F401RE 的 LED 呼吸燈專案：
PA5、active-high、2 秒週期，UART 為 sysbus.usart2。
接著呼叫 project_build 和 project_artifacts，列出產生的 ELF、BIN、HEX。
```

`project_create` 會建立程式碼骨架、Renode 情境和測試契約。`project_build` 可驗證建置流程；若使用主機 C compiler，產生的是 host ELF，**不能**載入 STM32 模擬器。

要做完整模擬驗證，專案需要 CMSIS/HAL、startup code、linker script 與 `arm-none-eabi-gcc` toolchain，並產出 `EM_ARM`（machine type `40`）的 ELF。完成後要求 agent：

```text
請使用 renode_verify_project 驗證 /tmp/led-breathing 的 ARM ELF，
回報載入的 firmware、模擬器狀態、virtual time 與 assertions。
```

## 5. GUI 與 UART Analyzer（選用）

原生 GUI 需要 Renode 的 GTK/桌面相依套件。確認直接執行 Renode 可以開啟視窗後，在任何 agent host 的 `--renode ...` 後加入 `--show-ui`，再開啟新的 agent session。

Codex CLI 的重新設定方式：

```sh
codex mcp remove renode
# 重新執行第 2 步的 codex mcp add，並在 --renode ... 後加入 --show-ui
```

然後在新的 agent session 輸入：

```text
請啟動 Renode，載入定義 sysbus.usart2 的板級情境，並呼叫
renode_open_uart_analyzer，peripheral 為 sysbus.usart2。
```

若未加 `--show-ui`，MCP 仍可執行模擬和讀取 UART/monitor 資訊，但不會顯示原生 Analyzer 視窗。

目前 UART Analyzer 視窗供人員觀察；MCP 尚未提供擷取視窗畫面或將 UART 文字串流回 agent 的專屬工具。

## 目前限制

- `project_create` 只建立與 toolchain 無關的 CMake 骨架；它不會從 datasheet 產生 HAL/CMSIS、startup code、linker script 或完整板級週邊模型。
- `datasheet` 欄位只記錄本機檔案路徑並回報是否存在，不會解析 datasheet。
- 使用主機編譯器的 `project_build` 只會產生 host ELF；STM32 驗證需要 `arm-none-eabi` toolchain 與 `EM_ARM` ELF。
- `renode_verify_project` 檢查 ELF 架構、載入韌體、啟動模擬並回傳 assertions；它**不會執行 assertions，也不會證明 GPIO/PWM 行為正確**。
- 仍須提供正確的板級 `.repl`/`.resc`。Renode 模擬不能取代最終的 HIL 測試、實體板測試或燒錄流程。

## 可用工具

| 工具 | 用途 |
| --- | --- |
| `project_create` | 建立韌體、Renode scenario 與測試契約。 |
| `project_build` | 執行建置並找出 ELF/BIN/HEX。 |
| `project_artifacts` | 列出 firmware artifacts。 |
| `renode_start` / `renode_stop` | 管理 Renode session。 |
| `renode_load_elf` | 將 ARM ELF 載入目前 machine。 |
| `renode_verify_project` / `renode_run_project` | 載入 ARM ELF、啟動模擬並回傳報告。 |
| `renode_system_info` | 取得 virtual time 與狀態。 |
| `renode_command` | 執行允許的 Renode monitor 指令。 |
| `renode_open_uart_analyzer` | 開啟原生 UART Analyzer，需要 GUI。 |

## 本機開發測試

在 Renode repository 根目錄執行：

```sh
python3 -m unittest discover -s tools/renode_mcp_server -p 'test_*.py'
```

## 疑難排解

- `renode` 不在 PATH：將 `--renode` 指向 Renode 的絕對路徑。
- 找不到 .NET runtime：設定 `DOTNET_ROOT`，並將其加入 MCP 的 `PATH`。
- `could not reserve a local Renode monitor port`：確認本機安全軟體沒有封鎖 loopback TCP，並停止殘留的 Renode process。
- GUI 自動退回 console：先使用 headless 模式；之後安裝 Renode 所需的 GTK/桌面相依套件，再使用 `--show-ui`。
- `renode_verify_project` 拒絕 ELF：請使用 ARM 交叉編譯器，而非主機編譯器。
