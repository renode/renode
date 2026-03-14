import sys
import asyncio
from PySide6.QtWidgets import QApplication
from qasync import QEventLoop
from ui.main_window import MainWindow
from backend.async_bridge import RenodeBridge

def main():
    app = QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)

    bridge = RenodeBridge()
    window = MainWindow(bridge)
    window.show()

    with loop:
        loop.run_forever()

if __name__ == "__main__":
    main()
