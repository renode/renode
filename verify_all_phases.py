import sys
import asyncio
import logging
import unittest
from unittest.mock import MagicMock, patch

# Add project root to path
sys.path.append('.')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("VerifyAll")

class TestRenodeUI(unittest.TestCase):
    def setUp(self):
        logger.info(f"Starting test: {self._testMethodName}")

    def test_backend_wrapper(self):
        """Verify RenodeWrapper initializes and methods work (Mock or Real)."""
        from backend.renode_wrapper import RenodeWrapper
        wrapper = RenodeWrapper()
        
        # Test basic methods don't crash
        wrapper.load_script("test.resc")
        wrapper.start()
        self.assertTrue(wrapper.running)
        wrapper.pause()
        self.assertFalse(wrapper.running)
        wrapper.reset()
        self.assertFalse(wrapper.running)
        val = wrapper.read_memory(0x1000, 4)
        self.assertIsNotNone(val)

    def test_backend_bridge(self):
        """Verify RenodeBridge async methods."""
        from backend.async_bridge import RenodeBridge
        
        # We need an event loop for async tests
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        bridge = RenodeBridge()
        
        async def run_bridge_tests():
            await bridge.load_script("test.resc")
            await bridge.start()
            await bridge.pause()
            await bridge.reset()
            val = await bridge.read_memory(0x1000, 4)
            return val

        val = loop.run_until_complete(run_bridge_tests())
        self.assertIsNotNone(val)
        loop.close()

    def test_ui_instantiation(self):
        """Verify MainWindow and Widgets can be instantiated."""
        from PySide6.QtWidgets import QApplication
        from ui.main_window import MainWindow
        from backend.async_bridge import RenodeBridge

        # Create QApplication if it doesn't exist
        app = QApplication.instance()
        if not app:
            app = QApplication(sys.argv)

        bridge = RenodeBridge()
        window = MainWindow(bridge)
        
        # Check UI components exist
        self.assertIsNotNone(window.load_btn)
        self.assertIsNotNone(window.start_btn)
        self.assertIsNotNone(window.pause_btn)
        self.assertIsNotNone(window.reset_btn)
        self.assertIsNotNone(window.memory_watch)
        self.assertIsNotNone(window.log_view)
        
        # Check initial state
        self.assertFalse(window.pause_btn.isEnabled())
        self.assertTrue(window.start_btn.isEnabled())

    def test_memory_watch_widget(self):
        """Verify MemoryWatchWidget functionality."""
        from PySide6.QtWidgets import QApplication
        from ui.widgets.memory_watch import MemoryWatchWidget

        app = QApplication.instance()
        if not app:
            app = QApplication(sys.argv)

        widget = MemoryWatchWidget()
        
        # Test adding a watch via mock dialog
        with patch('ui.widgets.memory_watch.AddWatchDialog') as MockDialog:
            instance = MockDialog.return_value
            instance.exec.return_value = True
            instance.get_data.return_value = {
                "address": "0x1000",
                "name": "Test",
                "type": "Word"
            }
            
            initial_row_count = widget.table.rowCount()
            widget.add_watch()
            self.assertEqual(widget.table.rowCount(), initial_row_count + 1)
            
            # Verify data in table
            self.assertEqual(widget.table.item(0, 0).text(), "0x1000")
            self.assertEqual(widget.table.item(0, 1).text(), "Test")
        
        # Test removing a watch
        widget.table.selectRow(0)
        widget.remove_watch()
        self.assertEqual(widget.table.rowCount(), initial_row_count)

if __name__ == '__main__':
    unittest.main()
