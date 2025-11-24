# Renode UI Implementation Roadmap

This document breaks down the development of the Renode Async UI into small, verifiable steps. Each step is designed to be a single, self-contained task for an AI coding assistant.

## General Guidelines
*   **Directory Structure**: Keep all UI components (windows, widgets, dialogs) strictly within the `ui/` folder. Do not scatter UI code in the root or backend directories.

## Phase 1: Foundation & Setup

### Task 1.1: Project Skeleton & Dependencies
*   **Goal**: Create the directory structure and install dependencies.
*   **Instructions**:
    1.  Create the folder structure as defined in `ui_planning.md` (Section 6).
    2.  Create a `requirements.txt` containing `PySide6`, `qasync`, and `psutil` (for process management if needed). *Note: `pyrenode3` might need manual installation or specific instructions.*
    3.  Create a `main.py` that simply launches a blank PySide6 window to verify the environment works.
*   **Verification**: Run `python main.py` and see a blank window.

### Task 1.2: Async Event Loop Integration
*   **Goal**: Integrate `qasync` so we can use `asyncio` with Qt.
*   **Instructions**:
    1.  Modify `main.py` to use `qasync.QEventLoop`.
    2.  Create a simple async function (e.g., `async def hello_delay()`) that prints "Hello" after 1 second.
    3.  Trigger this function from a button in the main window to prove the UI doesn't freeze while waiting.
*   **Verification**: Click the button, ensure the UI remains responsive (e.g., window can be moved) during the 1-second delay.

## Phase 2: Backend Integration (The "Mock" Approach)

### Task 2.1: Abstract Renode Wrapper
*   **Goal**: Create the interface for communicating with Renode, initially using mocks.
*   **Instructions**:
    1.  Create `backend/renode_wrapper.py`.
    2.  Define a class `RenodeWrapper` with methods: `load_script(path)`, `start()`, `pause()`, `reset()`, `read_memory(addr, type)`.
    3.  Implement these methods with **dummy `time.sleep()` calls** (e.g., 0.5s) and print statements to simulate work. This allows UI development without a running Renode instance yet.
*   **Verification**: Import the class in a test script and call methods; verify they "block" for the sleep duration.

### Task 2.2: Async Bridge
*   **Goal**: Create the non-blocking bridge that the UI will actually call.
*   **Instructions**:
    1.  Create `backend/async_bridge.py`.
    2.  Create `RenodeBridge` class that holds an instance of `RenodeWrapper`.
    3.  Implement async methods that use `loop.run_in_executor` to call the blocking `RenodeWrapper` methods.
*   **Verification**: Update the `main.py` test to call `await bridge.start()` and ensure the UI doesn't freeze during the mock sleep.

## Phase 3: Core UI Features
 
 ### Task 3.1: Simulation Controls UI
 *   **Goal**: Add the control buttons and status display.
 *   **Instructions**:
     1.  Update `ui/main_window.py` to add "Load Script", "Start", "Pause", "Reset" buttons.
     2.  Add a "Status" label (e.g., "Stopped", "Running").
     3.  Connect buttons to the `RenodeBridge` methods.
     4.  Update the status label based on the called action.
 *   **Verification**: Clicking "Start" should disable the Start button, enable Pause, update status to "Running", and log the action (via the mock backend). [x]
 
 ### Task 3.2: File Picker for Scripts
 *   **Goal**: Implement the file selection logic.
 *   **Instructions**:
     1.  Connect the "Load Script" button to a `QFileDialog`.
     2.  Pass the selected path to `bridge.load_script()`.
     3.  Handle the case where no file is selected.
 *   **Verification**: Select a dummy file, see the path printed by the mock backend. [x]
 
 ## Phase 4: Memory Monitor (The Complex Widget)
 
 ### Task 4.1: Memory Watch Widget Layout
 *   **Goal**: Create the visual component for the watch list.
 *   **Instructions**:
     1.  Create `ui/widgets/memory_watch.py`.
     2.  Implement a `QTableWidget` with columns: Address, Name, Type, Value.
     3.  Add "Add Watch" and "Remove Watch" buttons.
     4.  Implement a dialog to add a new watch (Address, Name, Type).
 *   **Verification**: Run the app, add a few items to the list, and verify they appear in the table. [x]
 
 ### Task 4.2: Polling Loop
 *   **Goal**: Implement the periodic update loop.
 *   **Instructions**:
     1.  In `main_window.py` (or a dedicated controller), create an `asyncio` task that runs `while True:` when simulation is running.
     2.  In the loop: `await asyncio.sleep(0.5)`, then iterate through watched addresses and call `bridge.read_memory()`.
     3.  Update the table values with the returned (mock) data.
 *   **Verification**: Start simulation. The table values should update every 0.5s (mock the values to increment or change randomly to prove it works). [x]

## Phase 5: Real Integration & Polish

### Task 5.1: Connect Real PyRenode3
*   **Goal**: Replace the mock with the real library.
*   **Instructions**:
    1.  Modify `backend/renode_wrapper.py` to import `pyrenode3`.
    2.  Implement the actual calls to `pyrenode3` methods.
    3.  Add error handling for `System.Exception`.
*   **Verification**: Run with a real `.resc` file and verify Renode actually starts. [x]

### Task 5.2: Logging & Error Handling
*   **Goal**: Display logs and errors to the user.
*   **Instructions**:
    1.  Add a `QTextEdit` for logs in the main window.
    2.  Redirect Python stdout/stderr or capture Renode logs to this text area.
    3.  Add `try/except` blocks in `async_bridge.py` to catch backend errors and show `QMessageBox` alerts.
*   **Verification**: Trigger a fake error (e.g., load non-existent file) and verify an alert pops up. [x]

## Phase 6: Documentation

### Task 6.1: User Guide
*   **Goal**: Create a guide for end-users.
*   **Instructions**:
    1.  Create `docs/user_guide.md`.
    2.  Document how to install, launch, and use the UI.
    3.  Include screenshots (if possible) or descriptions of the controls.
*   **Verification**: Review the markdown file for clarity and completeness.

### Task 6.2: Developer Documentation
*   **Goal**: Document the architecture for future contributors.
*   **Instructions**:
    1.  Create `docs/developer_guide.md`.
    2.  Explain the `qasync` integration and the `RenodeWrapper` pattern.
    3.  Document how to add new widgets or extend the API.
*   **Verification**: Ensure the guide explains the "why" behind the async architecture.
