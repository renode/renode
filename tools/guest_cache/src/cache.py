#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import math
import random
import time
from typing import List


class CacheLine:
    """
    Represents a cache line in a cache set.

    tag (int): The tag of the cache line.
    use_count (int): Used for replacement policies.
    insertion_time (float): The time when the cache line was inserted.
    last_access_time (float): The time when the cache line was last accessed.
    free (bool): Indicates if the line contains valid data.
    """

    def __init__(self):
        self.init()

    def init(self, tag: int = 0, free: bool = True):
        self.tag = tag
        self.free = free
        self.use_count: int = 0
        self.insertion_time: float = time.time()
        self.last_access_time: float = 0

    def __str__(self) -> str:
        return f"[CacheLine]: tag: {self.tag:b}, free: {self.free}, use: {self.use_count}, insertion: {self.insertion_time}, last access: {self.last_access_time}"


class Cache:
    """
    Cache memory model.

    name (str): Cache name, used in the `printd` debug helpers.
    cache_width (int): log2(cache_size).
    block_width (int): log2(cache_block_size).
    memory_width (int): log2(memory_size).

    lines_per_set (int): cache mapping policy selection:
        * -1 for fully associative
        * 1 for direct mapping
        * 2^n for n-way associativity

    replacement_policy (str | None): Selected line eviction policy (defaults to None):
        * FIFO: first in first out
        * LRU: least recently used
        * LFU: least frequently used
        * None: random

    debug (bool): print debug messages (defaults to False).
    """

    def __init__(
        self,
        name: str,
        cache_width: int,
        block_width: int,
        memory_width: int,
        lines_per_set: int,
        replacement_policy: str | None = None,
        debug: bool = False
    ):
        self.name = name
        self.debug = debug

        # Width of the memories
        self._cache_width = cache_width
        self._block_width = block_width
        self._memory_width = memory_width

        # Convert width to size in bytes
        self._cache_size = 2 ** self._cache_width
        self._block_size = 2 ** self._block_width
        self._memory_size = 2 ** self._memory_width

        self._num_lines = self._cache_size // self._block_size
        self._lines = [CacheLine() for i in range(self._num_lines)]

        if lines_per_set == -1:
            # special configuration case for fully associative mapping
            lines_per_set = self._num_lines

        if not (lines_per_set & (lines_per_set - 1) == 0) or lines_per_set == 0:
            raise Exception('Lines per set must be a power of two (1, 2, 4, 8, ...)')

        self._lines_per_set = lines_per_set
        self._sets = self._num_lines // lines_per_set
        self._set_width = int(math.log(self._sets, 2))

        self._replacement_policy = replacement_policy if replacement_policy is not None else 'RAND'

        # Statistics
        self.misses = 0
        self.hits = 0
        self.invalidations = 0
        self.flushes = 0

    def read(self, addr: int) -> None:
        sset = self._addr_get_set(addr)
        line = self._line_lookup(addr)
        self.printd(f'[read] attempt to fetch {hex(addr)} (set {sset})')

        if line and not line.free:
            self.printd('[read] rhit')
            self.hits += 1
            line.use_count += 1
            line.last_access_time = time.time()
        else:
            self.printd('[read] rmiss')
            self.misses += 1
            self._load(addr)

    def write(self, addr: int) -> None:
        sset = self._addr_get_set(addr)
        line = self._line_lookup(addr)
        self.printd(f'[write] attempted write to {hex(addr)} (set {sset})')

        if line:
            self.printd('[write] whit')
            self.hits += 1
            line.last_access_time = time.time()
        else:
            self.printd('[write] wmiss')
            self.misses += 1
            self._load(addr)

    def flush(self) -> None:
        self.printd('[flush] flushing all lines!')
        self.flushes += 1
        self._lines = [CacheLine() for i in range(self._num_lines)]

    def _select_evicted_index(self, lines_in_set: list) -> int:
        if self._replacement_policy == 'RAND':
            return random.randint(0, self._lines_per_set - 1)
        elif self._replacement_policy == 'LFU':
            return min(range(len(lines_in_set)), key=lambda i: lines_in_set[i].use_count)
        elif self._replacement_policy == 'FIFO':
            return min(range(len(lines_in_set)), key=lambda i: lines_in_set[i].insertion_time)
        elif self._replacement_policy == 'LRU':
            return min(range(len(lines_in_set)), key=lambda i: lines_in_set[i].last_access_time)
        else:
            raise Exception(f"Unknown replacement policy: {self._replacement_policy}! Exiting!")

    def _load(self, addr: int) -> None:
        self.printd(f'[load] loading @ {hex(addr)} to cache from Main Memory')
        tag = self._addr_get_tag(addr)
        set_index = self._addr_get_set(addr)
        lines_in_set = self._get_lines_in_set(set_index)

        # Determine the index of the cache line to load into
        free_line_index = next((index for index, obj in enumerate(lines_in_set) if obj.free), None)
        if free_line_index is not None:
            index = free_line_index
            self.printd(f'[load] loaded new cache index: {free_line_index} in the set {set_index}')
        else:
            self.printd(f"[load] lines in set {set_index}:")
            self.printd(' selecting a line to invalidate:\n', '\n'.join(f'{index}: {line}' for index, line in enumerate(lines_in_set)), sep='')
            index = self._select_evicted_index(lines_in_set)
            self.printd(f'[load] invalidated index: {index} in the set {set_index}')
            self.invalidations += 1

        lines_in_set[index].init(tag, False)

    @staticmethod
    def _extract_bits(value: int, start_bit: int, end_bit: int) -> int:
        num_bits = end_bit - start_bit + 1
        mask = ((1 << num_bits) - 1) << start_bit
        extracted_bits = (value & mask) >> start_bit
        return extracted_bits

    def _addr_get_tag(self, addr: int) -> int:
        start = self._block_width + self._set_width
        end = self._memory_width
        return self._extract_bits(addr, start, end)

    def _addr_get_set(self, addr: int) -> int:
        start = self._block_width
        end = self._block_width + self._set_width - 1
        return self._extract_bits(addr, start, end)

    def _addr_get_offset(self, addr: int) -> int:
        start = 0
        end = self._block_width - 1
        return self._extract_bits(addr, start, end)

    def _get_lines_in_set(self, set_index: int) -> List[CacheLine]:
        line_index = set_index * self._lines_per_set
        return self._lines[
            line_index:
            line_index + self._lines_per_set
        ]

    def _line_lookup(self, addr: int) -> CacheLine | None:
        tag = self._addr_get_tag(addr)
        lines_in_set = self._get_lines_in_set(self._addr_get_set(addr))
        return next((line for line in lines_in_set if line.tag == tag), None)

    def printd(self, *args, **kwargs):
        if self.debug:
            print(f'[{self.name}]', *args, **kwargs)

    def print_addr_info(self, addr: int, format: str = 'hex') -> None:
        convop = {'bin': bin, 'hex': hex, 'dec': int}.get(format, hex)
        print(f'addr: {convop(addr)}')
        print(f'tag : {convop(self._addr_get_tag(addr))}')
        print(f'set : {convop(self._addr_get_set(addr))}')
        print(f'off : {convop(self._addr_get_offset(addr))}')

    def print_cache_info(self) -> None:
        print(f'{self.name} configuration:')
        print(f'Cache size:          {self._cache_size} bytes')
        print(f'Block size:          {self._block_size} bytes')
        print(f'Number of lines:     {self._num_lines}')
        print(f'Number of sets:      {self._sets} ({self._lines_per_set} lines per set)')
        print(f'Replacement policy:  {self._replacement_policy if self._replacement_policy is not None else "RAND"}')

        if self.debug:
            print(f'Cache block width:   {self._block_width} bits')
            print(f'Addressable memory:  {self._memory_size} bytes')
            tag_width = self._memory_width - self._block_width - self._set_width
            print('Addressing parameters:')
            print(f'Tag: {tag_width} bits')
            print(f'Set: {self._set_width} bits')
            print(f'Block: {self._block_width} bits\n')

        print()

    def print_hmr(self) -> None:
        ratio = (self.hits / ((self.hits + self.misses) if self.misses else 1)) * 100
        print(f'Misses: {self.misses}')
        print(f'Hits: {self.hits}')
        print(f'Invalidations: {self.invalidations}')
        print(f'Hit ratio: {round(ratio, 2)}%')

    def print_debug_lines(self, include_empty_tags: bool = False) -> None:
        tag_width = self._memory_width - self._block_width - self._set_width
        print(f'tag: {tag_width} bits')
        print(f'set: {self._set_width} bits')
        print(f'block: {self._block_width} bits')

        for id, line in enumerate(self._lines):
            if line.tag or include_empty_tags:
                print(line)
                if self._lines_per_set and (id + 1) % self._lines_per_set == 0:
                    print()
