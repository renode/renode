import argparse
from dataclasses import dataclass
from typing import Any


def add_args(parser: argparse.ArgumentParser):
    parser.add_argument(
        "--subset",
        dest="subset",
        default="1/1",
        type=subset,
        help="Run a subset of the tests. E.g. '1/2' for running half of the tests and '2/2' for the other half. This is useful when splitting up test execution between runners.",
    )


@dataclass
class Subset:
    segment: int
    max_segments: int

    def __init__(self, segment: int, max_segments: int) -> None:
        if segment <= 0 or segment > max_segments:
            raise ValueError(
                f"`segment` must be > 0 and <= {max_segments} but it is {segment}"
            )
        if max_segments <= 0:
            raise ValueError(
                f"`max_segments` must be at least 1 but it is {max_segments}"
            )

        self.segment = segment
        self.max_segments = max_segments


def subset(text: str) -> Subset:
    values = text.split("/")
    if len(values) != 2:
        raise ValueError("subset string format must be integer/integer")

    return Subset(int(values[0]), int(values[1]))


@dataclass
class GroupsSegment:
    """A collection of groups that are part of a subset."""

    subset: Subset
    test_file_paths: list[str]
    groups: list[tuple[str, list[Any]]]


def segment_groups(options) -> GroupsSegment:
    """
    Splits the test groups into equally sized (best-effort) segments and returns the current one.

    Segment size and current segment is based on the values provided by the `--subset` option.

    Remainder items are distributed into the first segments.

    E.g. splitting this array into 4 segments (remainders are marked with *):
      input: [0, 1, 2, 3, 4, 5, 6, 7, 8*, 9*, 10*]
    seg 1/4: [0, 1,  8*]
    seg 2/4: [2, 3,  9*]
    seg 3/4: [4, 5, 10*]
    seg 4/4: [6, 7]
    """
    groups = list(options.tests.items())  # so we can slice it up
    nr_groups = len(groups)
    max_segments = options.subset.max_segments

    # Make the chunk size small enough that each segment can have at least this many test groups.
    chunk_size = nr_groups // max_segments  # always rounds down
    segment_num = options.subset.segment
    segment_index = segment_num - 1  # input is 1-indexed, we want 0-indexed

    # Split into "perfect" segments, ignoring the remainder.
    segment_start_index = segment_index * chunk_size
    groups_segment = groups[segment_start_index : segment_start_index + chunk_size]

    # Get the nth remainder, unique per segment.
    # There cannot be more than one remainder per segment if they're distributed evenly,
    # otherwise the chunk size would have been larger.
    end_of_segments_index = max_segments * chunk_size
    remainder_index = end_of_segments_index + segment_index
    # We may have run out of remainders, so check that it exists before appending.
    if remainder_index < nr_groups:
        groups_segment.append(groups[remainder_index])

    segment_test_file_paths = [
        suite.path for (_, suites) in groups_segment for suite in suites
    ]
    return GroupsSegment(options.subset, segment_test_file_paths, groups_segment)
