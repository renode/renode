import asyncio
import logging
from PySide6.QtCore import QObject, Signal
from PySide6.QtWidgets import QMainWindow, QLabel, QVBoxLayout, QWidget, QPushButton, QHBoxLayout, QFileDialog, QMessageBox, QTextEdit

from ui.widgets.memory_watch import MemoryWatchWidget

class LogHandler(logging.Handler, QObject):
    log_signal = Signal(str)

    def __init__(self):
        logging.Handler.__init__(self)
        QObject.__init__(self)

    def emit(self, record):
        msg = self.format(record)
        self.log_signal.emit(msg)

class MainWindow(QMainWindow):
    def __init__(self, bridge):
        super().__init__()
        self.bridge = bridge
        self.setWindowTitle("Renode UI")
        self.resize(800, 600)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        self.layout = QVBoxLayout(central_widget)

        # Status Label
        self.status_label = QLabel("Status: Stopped")
        self.layout.addWidget(self.status_label)

        # Controls Layout
        controls_layout = QHBoxLayout()
        self.layout.addLayout(controls_layout)

        # Buttons
        self.load_btn = QPushButton("Load Script")
        self.load_btn.clicked.connect(self.load_script_handler)
        controls_layout.addWidget(self.load_btn)

        self.start_btn = QPushButton("Start")
        self.start_btn.clicked.connect(lambda: asyncio.ensure_future(self.start_simulation()))
        controls_layout.addWidget(self.start_btn)

        self.pause_btn = QPushButton("Pause")
        self.pause_btn.clicked.connect(lambda: asyncio.ensure_future(self.pause_simulation()))
        self.pause_btn.setEnabled(False)
        controls_layout.addWidget(self.pause_btn)

        self.reset_btn = QPushButton("Reset")
        self.reset_btn.clicked.connect(lambda: asyncio.ensure_future(self.reset_simulation()))
        controls_layout.addWidget(self.reset_btn)

        # Memory Watch Widget
        self.memory_watch = MemoryWatchWidget()
        self.layout.addWidget(self.memory_watch)

        # Log View
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.layout.addWidget(self.log_view)

        # Setup Logging
        self.log_handler = LogHandler()
        self.log_handler.log_signal.connect(self.log_view.append)
        logging.getLogger().addHandler(self.log_handler)
        logging.getLogger().setLevel(logging.INFO)

        # Monitoring Task
        self.monitor_task = None

    def load_script_handler(self):
        file_name, _ = QFileDialog.getOpenFileName(self, "Open Renode Script", "", "Renode Scripts (*.resc);;All Files (*)")
        if file_name:
            asyncio.ensure_future(self.load_script(file_name))

    async def load_script(self, path):
        try:
            await self.bridge.load_script(path)
            self.status_label.setText(f"Status: Loaded {path}")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    async def start_simulation(self):
        try:
            self.start_btn.setEnabled(False)
            self.pause_btn.setEnabled(True)
            self.status_label.setText("Status: Running")
            await self.bridge.start()
            
            if not self.monitor_task or self.monitor_task.done():
                self.monitor_task = asyncio.create_task(self.monitor_loop())
        except Exception as e:
            self.start_btn.setEnabled(True)
            self.pause_btn.setEnabled(False)
            self.status_label.setText("Status: Error")
            QMessageBox.critical(self, "Error", str(e))

    async def pause_simulation(self):
        try:
            self.start_btn.setEnabled(True)
            self.pause_btn.setEnabled(False)
            self.status_label.setText("Status: Paused")
            await self.bridge.pause()
            # Monitor loop will check bridge status or we can cancel it.
            # For now, let it run but it might just read same values or we can stop it.
            # Better to let it run if we want to see state changes, but usually we stop polling if paused?
            # The roadmap says "Runs while simulation is running".
            if self.monitor_task:
                self.monitor_task.cancel()
        except Exception as e:
            self.status_label.setText("Status: Error")
            QMessageBox.critical(self, "Error", str(e))

    async def reset_simulation(self):
        try:
            self.start_btn.setEnabled(True)
            self.pause_btn.setEnabled(False)
            self.status_label.setText("Status: Stopped")
            await self.bridge.reset()
            if self.monitor_task:
                self.monitor_task.cancel()
        except Exception as e:
            self.status_label.setText("Status: Error")
            QMessageBox.critical(self, "Error", str(e))

    async def monitor_loop(self):
        try:
            while True:
                # In a real app, check if simulation is actually running
                # For now, we assume if this task is running, we should poll
                
                # Iterate over watches
                # We need to access watches safely. 
                # Since we are in the same thread (asyncio on main thread), it's safe to read self.memory_watch.watches
                for i, watch in enumerate(self.memory_watch.watches):
                    try:
                        val = await self.bridge.read_memory(watch['address'], 4) # Default to 4 bytes for now
                        self.memory_watch.update_value(watch['row'], val)
                    except Exception as e:
                        logging.error(f"Error reading memory: {e}")
                
                await asyncio.sleep(0.5)
        except asyncio.CancelledError:
            pass
