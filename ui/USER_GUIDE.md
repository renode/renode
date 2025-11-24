# Renode Async UI User Guide

Welcome to the **Renode Async UI**, a modern, responsive graphical interface for the [Renode](https://renode.io/) simulation framework. This tool allows you to control Renode simulations, inspect memory, and view logs in a user-friendly environment.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Running the Application](#running-the-application)
4. [Interface Overview](#interface-overview)
    - [Simulation Controls](#simulation-controls)
    - [Memory Monitor](#memory-monitor)
    - [Logs](#logs)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following installed:

*   **Python 3.10** or higher.
*   **Renode**: The Renode framework must be installed on your system.
*   **Mono**: Required for `pyrenode3` to communicate with Renode (on Linux/macOS).

## Installation

1.  **Clone the Repository**:
    ```bash
    git clone <repository-url>
    cd renode
    ```

2.  **Create a Virtual Environment** (Recommended):
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate  # On Windows: .venv\Scripts\activate
    ```

3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
    *Note: `pyrenode3` is required for real simulation. If it's not available via pip, you may need to install it from source or ensure it's in your PYTHONPATH.*

## Running the Application

To start the UI, simply run the `main.py` script from the root directory:

```bash
python main.py
```

The main window should appear, ready for you to load a script.

## Interface Overview

### Simulation Controls

Located at the top of the window, these buttons control the simulation state:

*   **Load Script**: Opens a file dialog to select a Renode script (`.resc`). Loading a script initializes the simulation.
*   **Start**: Begins or resumes the simulation execution.
*   **Pause**: Pauses the simulation.
*   **Reset**: Resets the simulation to its initial state (reloads the script).

**Status Indicator**: A label next to the controls shows the current state (e.g., "Stopped", "Running", "Paused").

### Memory Monitor

The **Memory Watch** section allows you to inspect specific memory addresses in real-time.

1.  **Add Watch**: Click the "Add Watch" button to open a dialog.
    *   **Address**: Enter the hex address (e.g., `0x8000`).
    *   **Name**: Give it a friendly name (e.g., "Buffer").
    *   **Type**: Select the data type (Byte, Word, DWord, String).
2.  **View Values**: The table displays the current value at the watched addresses. Values update periodically when the simulation is running.
3.  **Remove Watch**: Select a row and click "Remove Watch" to stop monitoring that address.

### Logs

The **System Logs** area at the bottom displays important information:
*   Application startup and status messages.
*   Renode log output (standard output from the simulation).
*   Error messages and warnings (e.g., if a script fails to load).

## Troubleshooting

### "pyrenode3 not found" Warning
If you see a warning in the logs that `pyrenode3` was not found, the application has fallen back to **Mock Mode**.
*   **Effect**: You can still use the UI, but it won't control a real Renode instance. Simulation is simulated with timers.
*   **Fix**: Ensure `pyrenode3` is installed and accessible in your Python environment.

### Simulation doesn't start
*   Check the Logs area for error messages.
*   Verify that your `.resc` file is valid and works in the standard Renode CLI.
*   Ensure no other Renode instance is locking the resources.

### UI Freezes
The UI is designed to be asynchronous. If it freezes, it might be due to an extremely long blocking operation in the backend that isn't properly offloaded. Please report this as a bug.
