import asyncio
from backend.renode_wrapper import RenodeWrapper

class RenodeBridge:
    def __init__(self):
        self.wrapper = RenodeWrapper()
        self.loop = asyncio.get_event_loop()

    async def load_script(self, path: str):
        await self.loop.run_in_executor(None, self.wrapper.load_script, path)

    async def start(self):
        await self.loop.run_in_executor(None, self.wrapper.start)

    async def pause(self):
        await self.loop.run_in_executor(None, self.wrapper.pause)

    async def reset(self):
        await self.loop.run_in_executor(None, self.wrapper.reset)

    async def read_memory(self, addr: int, width: int) -> int:
        return await self.loop.run_in_executor(None, self.wrapper.read_memory, addr, width)
