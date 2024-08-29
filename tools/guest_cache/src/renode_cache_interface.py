#!/usr/bin/env python3
#
# Copyright (c) 2010-2024 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import argparse
import json

from pathlib import Path
from tqdm import tqdm

from cache import Cache
from presets import PRESETS


class RenodeLogInterface:
    def __init__(self, file: Path):
        self.fname = file
        self.count_insn_read = 0
        self.count_mem_read = 0
        self.count_mem_write = 0
        self.count_io_read = 0
        self.count_io_write = 0
        self.invalidate_on_io = False

    def configure_caches(
        self,
        l1i: Cache | None = None,
        l1d: Cache | None = None,
        invalidation_opcodes: list | None = None,
        invalidate_on_io: bool = False
    ) -> None:

        self.l1i = l1i
        self.l1d = l1d
        self.invalidation_opcodes = invalidation_opcodes if invalidation_opcodes else {}
        self.invalidate_on_io = invalidate_on_io

        for cache in [self.l1i, self.l1d]:
            if cache is not None:
                cache.print_cache_info()

    def simulate(self) -> None:
        """ Simulate the cache structure

        Due to _large_ trace files, parse the file line-by-line, and operate on caches this way.

        Renode ExecutionTracer outputs the following data:

        * `PC`: `OPCODE`
        * Memory{Write, Read} with address `ADDR`
        * MemoryIO{Write, Read} with address `ADDR`
        """

        lines = sum(1 for i in open(self.fname, 'rb'))
        with open(self.fname, 'r') as f:
            for line in tqdm(f, total=lines):
                # Handle instruction fetch
                # 0xPC: 0xOPCODE
                if ':' in line and self.l1i is not None:
                    self.count_insn_read += 1
                    pc, opcode = (int(value.strip(), 16) for value in line.split(":"))
                    if opcode in self.invalidation_opcodes:
                        cache_type = self.invalidation_opcodes[opcode]
                        getattr(self, f'l1{cache_type}').flush()
                    self.l1i.read(pc)
                # Handle I/O access
                # Memory{Read, Write} with address 0xADDRESS
                elif line.startswith('Memory') and self.l1d is not None:
                    parts = line.split()
                    address = int(parts[-1], 16)
                    match parts[0].lower().removeprefix('memory'):
                        case 'iowrite':
                            if self.invalidate_on_io:
                                self.l1d.flush()
                            self.count_io_write += 1
                        case 'ioread':
                            if self.invalidate_on_io:
                                self.l1d.flush()
                            self.count_io_read += 1
                        case 'write':
                            self.count_mem_write += 1
                            self.l1d.write(address)
                        case 'read':
                            self.count_mem_read += 1
                            self.l1d.read(address)
                        case _:
                            raise ValueError('Unsupported memory operation!')

    def print_analysis_results(self) -> None:
        if self.l1i:
            print(f'Instructions read: {self.count_insn_read}')
        if self.l1d:
            print(f'Total memory operations: {self.count_mem_read + self.count_mem_write} (read: {self.count_mem_read}, write {self.count_mem_write})')
            print(f'Total I/O operations: {self.count_io_read + self.count_io_write} (read: {self.count_io_read}, write {self.count_io_write})')

        print()
        for c in [self.l1i, self.l1d]:
            if c is not None:
                print(f'{c.name} results:')
                c.print_hmr()
                print()

    def save_results(self, filename: Path) -> None:
        data = {c.name: {'hit': c.hits, 'miss': c.misses, 'invalidations': c.invalidations}
                for c in [self.l1i, self.l1d] if c is not None}

        with open(filename, 'w') as f:
            json.dump(data, f)


def parse_arguments():
    parser = argparse.ArgumentParser(description='Cache Simulator')
    parser.add_argument('trace_file', type=str, help='The file containing the trace to process')
    parser.add_argument('--output', type=str, required=False, help='Filename where results will be saved (optional)')

    subparsers = parser.add_subparsers(help='Help for subcommands', dest='subcommand')

    preset_parser = subparsers.add_parser('presets', help='Run cache simulation using premade configuration presets')
    preset_parser.add_argument('preset', type=str, choices=list(PRESETS.keys()), help='Available presets')

    config_parser = subparsers.add_parser('config', help='Configure cache manually')
    config_parser.add_argument('--memory_width', type=int, required=True, help='System memory width')
    config_parser.add_argument('--invalidate_on_io', action='store_true', default=False, help='Invalidate L1 data cache on IO operations')

    cache_groups = {
        'Instruction cache configuration': ['l1i'],
        'Data cache configuration': ['l1d']
    }

    for group, cache in cache_groups.items():
        group_parser = config_parser.add_argument_group(group)
        for cache_type in cache:
            group_parser.add_argument(f'--{cache_type}_cache_width', type=int, help=f'Cache width for {cache_type}')
            group_parser.add_argument(f'--{cache_type}_block_width', type=int, help=f'Block width for {cache_type}')
            group_parser.add_argument(f'--{cache_type}_lines_per_set', type=int, help=f'Lines per set for {cache_type}. Set associativity: 2^n, n = (1, 2, 3, ...). -1 for fully associative, 1 for direct mapping.')
            group_parser.add_argument(f'--{cache_type}_replacement_policy', type=str, default=None, help=f'Replacement policy for {cache_type}')

    return parser.parse_args()


def configure_cache(args):
    l1i, l1d, opcodes, invalidate_on_io = None, None, None, None
    if args.subcommand == 'presets':
        preset = PRESETS[args.preset]
        l1i, l1d, opcodes, invalidate_on_io = preset.get('l1i'), preset.get('l1d'), preset.get('flush_opcodes'), preset.get('invalidate_on_io')
    elif args.subcommand == 'config':
        l1i = create_cache('l1i', args) if all_args_present(args, 'l1i') else None
        l1d = create_cache('l1d', args) if all_args_present(args, 'l1d') else None
        invalidate_on_io = args.invalidate_on_io
        if not any([l1i, l1d]):
            print('[!!!] Missing or invalid cache configuration. Aborting!')
            exit(1)
    return l1i, l1d, opcodes, invalidate_on_io


def all_args_present(args, prefix):
    return all(getattr(args, f'{prefix}_{attr}') is not None for attr in ['cache_width', 'block_width', 'lines_per_set'])


def create_cache(name, args):
    return Cache(
        name=name,
        cache_width=getattr(args, f'{name}_cache_width'),
        block_width=getattr(args, f'{name}_block_width'),
        memory_width=args.memory_width,
        lines_per_set=getattr(args, f'{name}_lines_per_set'),
        replacement_policy=getattr(args, f'{name}_replacement_policy')
    )


if __name__ == '__main__':
    args = parse_arguments()
    l1i, l1d, opcodes, invalidate_on_io = configure_cache(args)

    log = RenodeLogInterface(args.trace_file)
    log.configure_caches(l1i, l1d, opcodes, invalidate_on_io)
    log.simulate()
    log.print_analysis_results()

    if (filename := args.output) is not None:
        log.save_results(filename)
