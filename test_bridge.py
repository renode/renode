import asyncio
from backend.async_bridge import RenodeBridge
import time

async def test_bridge():
    print("Testing RenodeBridge...")
    bridge = RenodeBridge()
    
    start_time = time.time()
    await bridge.start()
    duration = time.time() - start_time
    print(f"Async Start took {duration:.2f}s")
    
    start_time = time.time()
    await bridge.load_script("test.resc")
    duration = time.time() - start_time
    print(f"Async Load script took {duration:.2f}s")
    
    print("RenodeBridge tests passed!")

if __name__ == "__main__":
    asyncio.run(test_bridge())
