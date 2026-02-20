from backend.renode_wrapper import RenodeWrapper
import time

def test_wrapper():
    print("Testing RenodeWrapper...")
    wrapper = RenodeWrapper()
    
    start_time = time.time()
    wrapper.start()
    duration = time.time() - start_time
    print(f"Start took {duration:.2f}s (expected ~0.2s)")
    assert duration >= 0.2
    
    start_time = time.time()
    wrapper.load_script("test.resc")
    duration = time.time() - start_time
    print(f"Load script took {duration:.2f}s (expected ~0.5s)")
    assert duration >= 0.5
    
    print("RenodeWrapper tests passed!")

if __name__ == "__main__":
    test_wrapper()
