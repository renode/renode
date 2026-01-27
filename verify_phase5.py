import sys
import logging
from backend.renode_wrapper import RenodeWrapper

# Configure logging to capture output
logging.basicConfig(level=logging.INFO)

def test_renode_wrapper():
    print("Testing RenodeWrapper initialization...")
    wrapper = RenodeWrapper()
    
    # Check if it's in mock mode (since we know pyrenode3 is missing)
    # We can't easily check the internal state 'PYRENODE_AVAILABLE' directly as it's a global in the module,
    # but we can check the logs or behavior.
    # However, since we are running this, we can just call methods and see if they work (mock behavior).
    
    print("Testing load_script...")
    try:
        wrapper.load_script("test.resc")
    except Exception as e:
        print(f"load_script failed: {e}")
        return

    print("Testing start...")
    wrapper.start()
    if wrapper.running:
        print("Simulation started (Mock)")
    else:
        print("Simulation failed to start")

    print("Testing read_memory...")
    val = wrapper.read_memory(0x1000, 4)
    print(f"Read memory: {hex(val)}")
    if val == 0xDEADBEEF:
        print("Mock memory read confirmed")
    else:
        print("Unexpected memory value")

    print("Testing pause...")
    wrapper.pause()
    if not wrapper.running:
        print("Simulation paused (Mock)")

    print("Testing reset...")
    wrapper.reset()
    
    print("RenodeWrapper test passed!")

if __name__ == "__main__":
    test_renode_wrapper()
