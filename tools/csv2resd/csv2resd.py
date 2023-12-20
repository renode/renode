#!/usr/bin/env python3
#
# Copyright (c) 2010-2023 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import argparse
import sys
from dataclasses import dataclass
from typing import List, Optional
import csv
import resd

from grammar import SAMPLE_TYPE, BLOCK_TYPE


@dataclass
class Mapping:
    sample_type: SAMPLE_TYPE
    map_from: List[str]
    map_to: Optional[List[str]]
    channel: int

    def remap(self, row):
        output = [self._retype(row[key]) for key in self.map_from]
        if self.map_to:
            output = dict(zip(self.map_to, output))
        if isinstance(output, list) and len(output) == 1:
            output = int(output[0])
        return output

    def _retype(self, value):
        try:
            if all(c.isdigit() for c in value.lstrip('-')):
                return int(value)
            elif all(c.isdigit() or c == '.' for c in value.lstrip('-')):
                return float(value)
            elif value[0] == '"' and value[-1] == '"':
                return value[1:-1]
        except ValueError:
            return value


def parse_mapping(mapping):
    chunks = mapping.split(':')

    if len(chunks) >= 3 and not chunks[2]:
        chunks[2] = '_'

    if not all(chunks) or (len(chunks) < 2 or len(chunks) > 4):
        print(f'{mapping} is invalid mapping')
        return None

    possible_types = [type_ for type_ in SAMPLE_TYPE.encmapping if chunks[0].lower() in type_.lower()]
    if not possible_types:
        print(f'Invalid type: {chunks[0]}')
        print(f'Possible types: {", ".join(SAMPLE_TYPE.ksymapping.values())}')
        return None

    if len(possible_types) > 1:
        print(f'More than one type matches: {", ".join(type_ for _, type_ in possible_types)}')
        return None

    type_ = possible_types[0]
    map_from = chunks[1].split(',')
    map_to = chunks[2].split(',') if len(chunks) >= 3 and chunks[2] != '_' else None
    channel = int(chunks[3]) if len(chunks) >= 4 else 0

    return type_, map_from, map_to, channel


def parse_arguments():
    arguments = sys.argv[1:]

    entry_parser = argparse.ArgumentParser()
    entry_parser.add_argument('-i', '--input', required=True, help='path to csv file')
    entry_parser.add_argument('-m', '--map', action='append', type=parse_mapping,
        help='mapping in format <type>:<index/label>[:<to_property>:<channel>], multiple mappings are possible')
    entry_parser.add_argument('-s', '--start-time', type=int, help='start time (in nanoseconds)')
    entry_parser.add_argument('-f', '--frequency', type=float, help='frequency of the data (in Hz)')
    entry_parser.add_argument('-t', '--timestamp', help='index/label of a column in the csv file for the timestamps (in nanoseconds)')
    entry_parser.add_argument('-o', '--offset', type=int, default=0, help='number of samples to skip from the beginning of the file')
    entry_parser.add_argument('-c', '--count', type=int, default=sys.maxsize, help='number of samples to parse')
    entry_parser.add_argument('output', nargs='?', help='output file path')

    if not arguments or any(v in ('-h', '--help') for v in arguments):
        entry_parser.parse_args(['--help'])
        sys.exit(0)

    split_indices = [i for i, v in enumerate(arguments) if v in ('-i', '--input')]
    split_indices.append(len(arguments))
    subentries = [arguments[a:b] for a, b in zip(split_indices, split_indices[1:])]

    entries = []
    for subentry in subentries:
        parsed = entry_parser.parse_args(subentry)
        if parsed.frequency is None and parsed.timestamp is None:
            print(f'{parsed.input}: either frequency or timestamp should be provided')
            sys.exit(1)
        if parsed.frequency and parsed.timestamp:
            print(f'{parsed.input}: cannot provide both frequency and timestamp')
            sys.exit(1)

        entries.append(parsed)

    if entries and entries[-1].output is None:
        entry_parser.parse_args(['--help'])
        sys.exit(1)

    return entries


def map_source(labels, source):
    if source is None:
        return None

    source = int(source) if all(c.isdigit() for c in source) else source
    if isinstance(source, int) and 0 <= source < len(labels):
        source = labels[source]

    if source not in labels:
        print(f'{source} is invalid source')
        return None

    return source


def rebuild_mapping(labels, mapping):
    map_from = mapping[1]

    for i, src in enumerate(map_from):
        src = map_source(labels, src)
        if src is None:
            return None
        map_from[i] = src

    return Mapping(mapping[0], map_from, mapping[2], mapping[3])


if __name__ == '__main__':
    arguments = parse_arguments()
    output_file = arguments[-1].output

    resd_file = resd.RESD(output_file)
    for group in arguments:
        block_type = BLOCK_TYPE.ARBITRARY_TIMESTAMP
        if group.frequency is not None:
            block_type = BLOCK_TYPE.CONSTANT_FREQUENCY

        with open(group.input, 'rt') as csv_file:
            csv_reader = csv.DictReader(csv_file)
            labels = mapping = None
            timestamp_source = None

            to_skip = group.offset
            to_parse = group.count

            for row in csv_reader:
                if labels is None:
                    labels = list(row.keys())
                    mappings = [rebuild_mapping(labels, mapping) for mapping in group.map]
                    if block_type == BLOCK_TYPE.ARBITRARY_TIMESTAMP:
                        timestamp_source = map_source(labels, group.timestamp)
                        if timestamp_source is None:
                            sys.exit(1)

                if to_skip > 0:
                    to_skip -= 1
                    continue

                if to_parse == 0:
                    break

                for mapping in mappings:

                    block = resd_file.get_block_or_create(mapping.sample_type, block_type, mapping.channel)
                    if block_type == BLOCK_TYPE.CONSTANT_FREQUENCY:
                        block.add_sample(mapping.remap(row))
                    else:
                        block.add_sample(mapping.remap(row), int(row[timestamp_source]))

                to_parse -= 1

        for mapping in mappings:
            block = resd_file.get_block(mapping.sample_type, mapping.channel)
            if block_type == BLOCK_TYPE.CONSTANT_FREQUENCY:
                block.frequency = group.frequency
            if group.start_time is not None:
                block.start_time = group.start_time

        resd_file.flush()
