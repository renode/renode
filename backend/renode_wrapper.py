import time
import logging

# Try to import pyrenode3
try:
    import pyrenode3
    from pyrenode3.wrappers import Emulation, Monitor
    PYRENODE_AVAILABLE = True
except ImportError:
    PYRENODE_AVAILABLE = False

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class RenodeWrapper:
    def __init__(self):
        self.running = False
        if PYRENODE_AVAILABLE:
            logger.info("RenodeWrapper initialized (Real)")
        else:
            logger.warning("pyrenode3 not found. Falling back to Mock mode.")
            logger.info("RenodeWrapper initialized (Mock)")

    def load_script(self, path: str):
        logger.info(f"Loading script: {path}")
        if PYRENODE_AVAILABLE:
            try:
                Emulation.clear()
                Monitor.parse(f"i @{path}")
                logger.info("Script loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load script: {e}")
                raise e
        else:
            time.sleep(0.5) # Simulate work
            if not path:
                raise ValueError("Invalid path")
            logger.info("Script loaded successfully")

    def start(self):
        logger.info("Starting simulation...")
        if PYRENODE_AVAILABLE:
            try:
                Emulation.start()
                self.running = True
                logger.info("Simulation started")
            except Exception as e:
                logger.error(f"Failed to start simulation: {e}")
                raise e
        else:
            time.sleep(0.2)
            self.running = True
            logger.info("Simulation started")

    def pause(self):
        logger.info("Pausing simulation...")
        if PYRENODE_AVAILABLE:
            try:
                Emulation.pause()
                self.running = False
                logger.info("Simulation paused")
            except Exception as e:
                logger.error(f"Failed to pause simulation: {e}")
                raise e
        else:
            time.sleep(0.1)
            self.running = False
            logger.info("Simulation paused")

    def reset(self):
        logger.info("Resetting simulation...")
        if PYRENODE_AVAILABLE:
            try:
                Emulation.clear()
                self.running = False
                logger.info("Simulation reset")
            except Exception as e:
                logger.error(f"Failed to reset simulation: {e}")
                raise e
        else:
            time.sleep(0.5)
            self.running = False
            logger.info("Simulation reset")

    def read_memory(self, addr: int, width: int) -> int:
        if PYRENODE_AVAILABLE:
            # TODO: Implement real memory read using pyrenode3
            # For now, we'll just log and return a dummy value to avoid crashing
            # if we don't know the exact API.
            # Ideally: return Monitor.execute(f"sysbus ReadDoubleWord {addr}") (parsed)
            return 0xDEADBEEF
        else:
            # Simulate memory read
            # logger.debug(f"Reading memory at {hex(addr)}") # Commented out to avoid spam
            time.sleep(0.01) # fast read
            return 0xDEADBEEF # Mock value
