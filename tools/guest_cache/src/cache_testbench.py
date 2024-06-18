#!/usr/bin/env python3
#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

from cache import Cache
from typing import Dict


class TestLogInterface:
    def __init__(self):
        # Statistics
        self.count_insn_read = 0
        self.count_mem_read = 0
        self.count_mem_write = 0
        self.count_io_read = 0
        self.count_io_write = 0

    def configure_caches(self, cache: Cache) -> None:
        self.cache = cache

    def simulate(self, data: list[Dict[str, int]]):
        for access in data:
            for type, addr in access.items():
                match type:
                    case 'mw':
                        self.count_mem_write += 1
                        self.cache.write(addr)
                    case 'mr':
                        self.count_mem_read += 1
                        self.cache.read(addr)
                    case 'ior':
                        self.count_io_write += 1
                    case 'iow':
                        self.cache.flush()
                        self.count_io_read += 1
                    case _:
                        raise ValueError('Unsupported memory operation!')


def tag_in_cache(cache: Cache, tag: int) -> bool:
    return any(line.tag == tag for line in cache._lines)


def test_fully_associative():
    ''' Test scenario: fully associative cache

    CPU Address space: 1024 bytes (1KiB)

    cache:
    * msize:  1024 bytes
    * csize:  64 bytes
    * bsize:  4 bytes
    * clines: 16
    * csets:  1 (16 lines per set)

    Widths:
    * tag: 8 bits
    * set: 0 bits
    * block: 2 bits
    '''
    cache = Cache(
        name='fully_associative',
        cache_width=6,
        block_width=2,
        memory_width=10,
        lines_per_set=-1,
        replacement_policy='FIFO',
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    '''
    Fill all cache lines (16 different tags)

    Expected outcome:
    * misses += 16
    '''
    test.simulate([
        {'mr': 0b00000000_00},
        {'mr': 0b00000001_00},
        {'mr': 0b00000010_00},
        {'mr': 0b00000011_00},
        {'mr': 0b00000100_00},
        {'mr': 0b00000101_00},
        {'mr': 0b00000110_00},
        {'mr': 0b00000111_00},
        {'mr': 0b00001000_00},
        {'mr': 0b00001001_00},
        {'mr': 0b00001010_00},
        {'mr': 0b00001011_00},
        {'mr': 0b00001100_00},
        {'mr': 0b00001101_00},
        {'mr': 0b00001110_00},
        {'mr': 0b00001111_00},
    ]
    )
    assert test.cache.hits == 0
    assert test.cache.misses == 16
    assert test.cache.invalidations == 0

    '''
    Read memory from cached lines

    Expected outcome:
    * hits += 16
    '''
    test.simulate([
        {'mr': 0b00000000_11},
        {'mr': 0b00000001_11},
        {'mr': 0b00000010_11},
        {'mr': 0b00000011_11},
        {'mr': 0b00000100_11},
        {'mr': 0b00000101_11},
        {'mr': 0b00000110_11},
        {'mr': 0b00000111_11},
        {'mr': 0b00001000_11},
        {'mr': 0b00001001_11},
        {'mr': 0b00001010_11},
        {'mr': 0b00001011_11},
        {'mr': 0b00001100_11},
        {'mr': 0b00001101_11},
        {'mr': 0b00001110_11},
        {'mr': 0b00001111_11},
    ]
    )
    assert test.cache.hits == 16
    assert test.cache.misses == 16
    assert test.cache.invalidations == 0

    '''
    Read memory from non-cached addresses

    Expected outcome:
    * misses += 16
    * invalidations += 16
    '''
    test.simulate([
        {'mr': 0b10000000_00},
        {'mr': 0b10000001_00},
        {'mr': 0b10000010_00},
        {'mr': 0b10000011_00},
        {'mr': 0b10000100_00},
        {'mr': 0b10000101_00},
        {'mr': 0b10000110_00},
        {'mr': 0b10000111_00},
        {'mr': 0b10001000_00},
        {'mr': 0b10001001_00},
        {'mr': 0b10001010_00},
        {'mr': 0b10001011_00},
        {'mr': 0b10001100_00},
        {'mr': 0b10001101_00},
        {'mr': 0b10001110_00},
        {'mr': 0b10001111_00},
    ]
    )
    assert test.cache.hits == 16
    assert test.cache.misses == 32
    assert test.cache.invalidations == 16

    '''
    IO writes should flush cache:

    Expected outcome:
    * hits += 2
    * missess += 1
    * invalidations should not change (flush != line eviction)
    '''
    test.simulate([
        {'iow': 0b00000000_00},  # invalidate all cache
        {'mr': 0b10000000_00},   # miss
        {'mr': 0b10000000_00},   # hit
        {'mr': 0b10000000_00},   # hit
    ]
    )
    assert test.cache.hits == 18
    assert test.cache.misses == 33
    assert test.cache.invalidations == 16

    '''
    Writes to addresses with cache miss should load data into cache block.

    Expected outcome:
    * hits += 2
    * missess += 1
    '''
    test.simulate([
        {'mw': 0b01000000_00},  # miss
        {'mr': 0b01000000_00},  # hit
        {'mr': 0b01000000_00},  # hit
    ]
    )
    assert test.cache.hits == 20
    assert test.cache.misses == 34
    assert test.cache.invalidations == 16

    print('Fully associative cache test success!')


def test_set_associative():
    ''' Test scenario: set associative cache

    CPU Address space: 1024 bytes (1KiB)

    cache:
    * msize:  1024 bytes
    * csize:  64 bytes
    * bsize:  4 bytes
    * clines: 16
    * csets:  4 (4 lines per set)

    Widths:
    * tag: 8 bits
    * set: 2 bits
    * block: 2 bits
    '''
    cache = Cache(
        name='set_associative',
        cache_width=6,
        block_width=2,
        memory_width=10,
        lines_per_set=4,
        replacement_policy='FIFO',
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    '''
    Load one cache line into each set

    Expected outcome:
    * misses += 4
    '''
    test.simulate([
        {'mr': 0b000000_00_00},  # Set 0
        {'mr': 0b000000_01_00},  # Set 1
        {'mr': 0b000000_10_00},  # Set 2
        {'mr': 0b000000_11_00},  # Set 3
    ])
    assert test.cache.hits == 0
    assert test.cache.misses == 4
    assert test.cache.invalidations == 0

    '''
    Try to load data blocks from loaded cache lines

    Expected outcome:
    * hits += 4
    '''
    test.simulate([
        {'mr': 0b000000_00_11},  # Set 0
        {'mr': 0b000000_01_11},  # Set 1
        {'mr': 0b000000_10_11},  # Set 2
        {'mr': 0b000000_11_11},  # Set 3
    ])
    assert test.cache.hits == 4
    assert test.cache.misses == 4
    assert test.cache.invalidations == 0

    '''
    Try to access data from aliased cache lines

    Expected outcome:
    * misses += 4
    * invalidations += 1
    '''
    test.simulate([
        {'mr': 0b000001_00_00},  # Set 0 (alias 1)
        {'mr': 0b000010_00_00},  # Set 0 (alias 2)
        {'mr': 0b000011_00_00},  # Set 0 (alias 3)
        {'mr': 0b000100_00_00},  # Set 0 (alias 4)
    ])
    assert test.cache.hits == 4
    assert test.cache.misses == 8
    assert test.cache.invalidations == 1

    print('Set associative cache test success!')


def test_direct_mapped():
    ''' Test scenario: direct mapped cache

    CPU Address space: 1024 bytes (1KiB)

    cache:
    * msize:  1024 bytes
    * csize:  64 bytes
    * bsize:  4 bytes
    * clines: 16
    * csets:  16 (1 line per set)

    Widths:
    * tag: 6 bits
    * set: 4 bits
    * block: 2 bits
    '''
    cache = Cache(
        name='direct_mapped',
        cache_width=6,
        block_width=2,
        memory_width=10,
        lines_per_set=1,
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    '''
    Fill each cache line uniquely

    Expected outcome:
    * misses += 16
    '''
    test.simulate([
        {'mr': 0b0000_0000_00},
        {'mr': 0b0000_0001_00},
        {'mr': 0b0000_0010_00},
        {'mr': 0b0000_0011_00},
        {'mr': 0b0000_0100_00},
        {'mr': 0b0000_0101_00},
        {'mr': 0b0000_0110_00},
        {'mr': 0b0000_0111_00},
        {'mr': 0b0000_1000_00},
        {'mr': 0b0000_1001_00},
        {'mr': 0b0000_1010_00},
        {'mr': 0b0000_1011_00},
        {'mr': 0b0000_1100_00},
        {'mr': 0b0000_1101_00},
        {'mr': 0b0000_1110_00},
        {'mr': 0b0000_1111_00},
    ])
    assert test.cache.hits == 0
    assert test.cache.misses == 16
    assert test.cache.invalidations == 0

    '''
    Re-access each address to verify direct mapping

    Expected outcome:
    * hits += 16
    '''
    test.simulate([
        {'mr': 0b0000_0000_11},
        {'mr': 0b0000_0001_11},
        {'mr': 0b0000_0010_11},
        {'mr': 0b0000_0011_11},
        {'mr': 0b0000_0100_11},
        {'mr': 0b0000_0101_11},
        {'mr': 0b0000_0110_11},
        {'mr': 0b0000_0111_11},
        {'mr': 0b0000_1000_11},
        {'mr': 0b0000_1001_11},
        {'mr': 0b0000_1010_11},
        {'mr': 0b0000_1011_11},
        {'mr': 0b0000_1100_11},
        {'mr': 0b0000_1101_11},
        {'mr': 0b0000_1110_11},
        {'mr': 0b0000_1111_11},
    ])
    assert test.cache.hits == 16
    assert test.cache.misses == 16
    assert test.cache.invalidations == 0

    '''
    Access every alias - trash cache

    Expected outcome:
    * invalidations += 16
    * missess += 16
    '''
    test.simulate([
        {'mr': 0b0001_0000_11},
        {'mr': 0b0001_0001_11},
        {'mr': 0b0001_0010_11},
        {'mr': 0b0001_0011_11},
        {'mr': 0b0001_0100_11},
        {'mr': 0b0001_0101_11},
        {'mr': 0b0001_0110_11},
        {'mr': 0b0001_0111_11},
        {'mr': 0b0001_1000_11},
        {'mr': 0b0001_1001_11},
        {'mr': 0b0001_1010_11},
        {'mr': 0b0001_1011_11},
        {'mr': 0b0001_1100_11},
        {'mr': 0b0001_1101_11},
        {'mr': 0b0001_1110_11},
        {'mr': 0b0001_1111_11},
    ])
    assert test.cache.hits == 16
    assert test.cache.misses == 32
    assert test.cache.invalidations == 16

    print('Direct mapped cache test success!')


def test_fifo_cache():
    ''' Test scenario: FIFO cache replacement policy '''
    cache = Cache(
        name='fifo_cache',
        cache_width=4,
        block_width=2,
        memory_width=10,
        lines_per_set=4,
        replacement_policy='FIFO',
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    # Fill all cache lines
    test.simulate([
        {'mr': 0b00000000_00},  # tag 00
        {'mr': 0b00000001_00},  # tag 01
        {'mr': 0b00000010_00},  # tag 10
        {'mr': 0b00000011_00},  # tag 11
    ])
    for tag in [0b00, 0b01, 0b10, 0b11]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    # Access to force FIFO replacement
    test.simulate([
        {'mr': 0b00000100_00},  # FIFO replace tag 00 with tag 100
        {'mr': 0b00000101_00},  # FIFO replace tag 01 with tag 101
    ])
    for tag in [0b100, 0b101, 0b10, 0b11]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    print('FIFO cache test success!')


def test_lfu_cache():
    ''' Test scenario: LFU cache replacement policy '''
    cache = Cache(
        name='lfu_cache',
        cache_width=4,
        block_width=2,
        memory_width=10,
        lines_per_set=4,
        replacement_policy='LFU',
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    # Fill all cache lines
    test.simulate([
        {'mr': 0b00000000_00},  # tag 00
        {'mr': 0b00000001_00},  # tag 01
        {'mr': 0b00000010_00},  # tag 10
        {'mr': 0b00000011_00},  # tag 11
    ])
    for tag in [0b00, 0b01, 0b10, 0b11]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    # Increment usage counters
    test.simulate([
        {'mr': 0b00000001_00},  # access tag 01 (2 times)
        {'mr': 0b00000001_00},

        {'mr': 0b00000000_00},  # access tag 00 (3 times)
        {'mr': 0b00000000_00},
        {'mr': 0b00000000_00},

        {'mr': 0b00000011_00},  # access tag 11 (1 time)

        {'mr': 0b00000010_00},  # access tag 10 (4 times)
        {'mr': 0b00000010_00},
        {'mr': 0b00000010_00},
        {'mr': 0b00000010_00},
    ])

    # Load a new line into the cache. Tag 11 has the lowest usage
    # count, and will be replaced with the tag 100
    test.simulate([
        {'mr': 0b00000100_00},  # LFU replace tag 11 with tag 100
    ])
    for tag in [0b00, 0b01, 0b10, 0b100]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    print('LFU cache test success!')


def test_lru_cache():
    ''' Test scenario: LRU cache replacement policy '''
    cache = Cache(
        name='lru_cache',
        cache_width=4,
        block_width=2,
        memory_width=10,
        lines_per_set=4,
        replacement_policy='LRU',
    )

    test = TestLogInterface()
    test.configure_caches(cache)

    # Fill all cache lines
    test.simulate([
        {'mr': 0b00000000_00},  # tag 00
        {'mr': 0b00000001_00},  # tag 01
        {'mr': 0b00000010_00},  # tag 10
        {'mr': 0b00000011_00},  # tag 11
    ])
    for tag in [0b00, 0b01, 0b10, 0b11]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    # Simulate accessess to update last access time
    test.simulate([
        {'mr': 0b00000001_00},  # access tag 01
        {'mr': 0b00000000_00},  # access tag 00
        {'mr': 0b00000011_00},  # access tag 11
        {'mr': 0b00000010_00},  # access tag 10
    ])

    # Load a new line into the cache. Tag 01 has is
    # least recently used, and will be replaced with the tag 100
    test.simulate([
        {'mr': 0b00000100_00},  # LFU replace tag 01 with tag 100
    ])
    for tag in [0b00, 0b10, 0b11, 0b100]:
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)
        assert tag_in_cache(test.cache, tag)

    print('LRU cache test success!')


if __name__ == '__main__':
    test_fully_associative()
    test_set_associative()
    test_direct_mapped()

    test_fifo_cache()
    test_lfu_cache()
    test_lru_cache()
