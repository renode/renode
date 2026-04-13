import argparse
from dataclasses import asdict
from dataclasses import dataclass
from dataclasses import field
import heapq
import os
from typing import Any, Optional

import yaml


def add_args(parser: argparse.ArgumentParser):
    parser.add_argument(
        "--stats",
        dest="stats_file",
        action="store",
        default=None,
        help="Path to a file containing statistics about previous test runtimes. This is used by --subset to split based on segment duration rather than suite count.",
    )

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

    def __post_init__(self) -> None:
        if self.segment <= 0 or self.segment > self.max_segments:
            raise ValueError(
                f"`segment` must be > 0 and <= {self.max_segments} but it is {self.segment}"
            )
        if self.max_segments <= 0:
            raise ValueError(
                f"`max_segments` must be at least 1 but it is {self.max_segments}"
            )


def subset(text: str) -> Subset:
    values = text.split("/")
    if len(values) != 2:
        raise ValueError("subset string format must be integer/integer")

    return Subset(int(values[0]), int(values[1]))


@dataclass
class DurationDistribution:
    min: float = 0.0
    p50: float = 0.0
    p95: float = 0.0
    max: float = 0.0

    def get(self, stat: str) -> float:
        return getattr(self, stat)

    def add(self, stat: str, value: float):
        setattr(self, stat, self.get(stat) + value)

    def update_slowest(self, stat: str, value: float):
        if value > self.get(stat):
            setattr(self, stat, value)


@dataclass(frozen=True)
class SuiteStatistics:
    runs: int
    max_duration_seconds: float
    p95_duration_seconds: float
    p50_duration_seconds: float
    min_duration_seconds: float

    def to_distribution(self) -> DurationDistribution:
        return DurationDistribution(
            min=self.min_duration_seconds,
            p50=self.p50_duration_seconds,
            p95=self.p95_duration_seconds,
            max=self.max_duration_seconds,
        )


# The assumed runtime of tests which we don't yet have data on.
DEFAULT_RUNTIME_SECONDS = 60 * 10  # Let's be pessimistic about how fast a new test is.
DEFAULT_SUITE_DISTRIBUTION = DurationDistribution(
    max=DEFAULT_RUNTIME_SECONDS,
    p95=DEFAULT_RUNTIME_SECONDS,
    p50=DEFAULT_RUNTIME_SECONDS,
    min=DEFAULT_RUNTIME_SECONDS,
)


def parse_stats_file(path: os.PathLike) -> dict[str, DurationDistribution]:
    with open(path) as f:
        data = yaml.load(f, Loader=yaml.SafeLoader)
    return {
        suite_path: SuiteStatistics(**stats).to_distribution()
        for entry in data
        for suite_path, stats in entry.items()
    }


@dataclass
class SuiteBucket:
    id: int
    jobs: int
    suites: list[Any] = field(default_factory=list)
    totals: DurationDistribution = field(default_factory=DurationDistribution)
    slowest: DurationDistribution = field(default_factory=DurationDistribution)

    def makespan(self, duration_stat: str = "p95") -> float:
        """Compute the estimated total duration of the bucket."""
        # Use 95th percentile duration by default, in order to pack the buckets pessimistically.
        # This should help the worst-case performance, when the slowest tests are near their p95.
        total_seconds = self.totals.get(duration_stat)
        if total_seconds == 0:
            return 0.0

        # Use Amdahl's law to take the slowest suite into account.
        sequential_fraction = self.slowest.get(duration_stat) / total_seconds
        return total_seconds * (
            sequential_fraction + (1 - sequential_fraction) / self.jobs
        )

    def makespan_info(
        self, stat: str = "p95"
    ) -> tuple[float, Optional[tuple[str, float]]]:
        makespan = self.makespan(stat)
        slowest_duration = self.slowest.get(stat)
        total = self.totals.get(stat)
        makespan_without_slowest = (total - slowest_duration) / self.jobs
        # Bottlenecked when removing the slowest suite would cause the bucket to
        # finish at least 50% earlier, i.e. it dominates the bucket's runtime.
        if makespan_without_slowest <= makespan * 0.5:
            slowest_suite = max(self.suites, key=lambda s: s.stats.get(stat))
            return makespan, (slowest_suite.suite.path, slowest_duration)
        return makespan, None

    def __lt__(self, other: "SuiteBucket") -> bool:
        """
        Order buckets based on estimated makespan,
        taking the number of concurrent workers into account.
        """
        return self.makespan() < other.makespan()


@dataclass
class GroupsSegment:
    """A collection of groups that are part of a subset."""

    subset: Subset
    test_file_paths: list[str]
    groups: list[tuple[str, list[Any]]]


def segment_groups(options) -> GroupsSegment:
    if options.stats_file is None:
        return segment_groups_simple(options)
    return segment_groups_based_on_stats(options)


def segment_groups_simple(options) -> GroupsSegment:
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

    # Split into "perfect" segments, ignoring the remaining items.
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


def segment_groups_based_on_stats(options) -> GroupsSegment:
    """
    Distributes test suites greedily using a longest-runtime-first algorithm.

    For tests that do not have any statistics, `DEFAULT_SUITE_STATS` is used.
    """
    groups: list[tuple[str, Any]] = flatten_groups(options.tests)
    stats: dict[str, DurationDistribution] = options.stats
    max_segments = options.subset.max_segments

    @dataclass(frozen=True)
    class TimedSuite:
        suite: Any
        group: str
        stats: DurationDistribution

    suites: list[TimedSuite] = []
    suites_missing_stats: list[str] = []

    # Ignore suite groupings, for now, and just convert them all to TimedSuite.
    # We do this because it allows us to split groups across different buckets.
    for group, suite in groups:
        if suite.path not in stats:
            suites_missing_stats.append(suite.path)
        suites.append(
            TimedSuite(suite, group, stats.get(suite.path, DEFAULT_SUITE_DISTRIBUTION))
        )

    if len(suites_missing_stats) > 0:
        print(
            f"Statistics about previous test runs missing for {len(suites_missing_stats)} suites:"
        )
        for suite_path in suites_missing_stats:
            print(f"  - {suite_path}")
        print("")

    buckets = [SuiteBucket(i, options.jobs) for i in range(max_segments)]
    # Use a min-heap to track the shortest-makespan bucket.
    heapq.heapify(buckets)

    # We start with the longest suites, to make sure they get started first.
    suites.sort(key=lambda timed_suite: timed_suite.stats.get("p95"), reverse=True)

    # Greedily assign suites to the bucket with the shortest makespan.
    # This will (roughly) distribute them evenly between the buckets.
    for suite in suites:
        shortest_bucket = heapq.heappop(buckets)

        for stat, duration in asdict(suite.stats).items():
            shortest_bucket.totals.add(stat, duration)
            shortest_bucket.slowest.update_slowest(stat, duration)

        shortest_bucket.suites.append(suite)
        heapq.heappush(buckets, shortest_bucket)

    # Sort by bucket ID to get deterministic indexing.
    buckets.sort(key=lambda b: b.id)

    # We need to compute all buckets due to the nature of the algorithm, but we only need one of them.
    subset_index = (
        options.subset.segment - 1  # Segments are 1-indexed, but we need 0-indexed.
    )
    subset_bucket = buckets[subset_index]

    # Not much point in printing this information unless multiple buckets are used,
    # since the durations printed won't reflect real-world job duration.
    if options.jobs > 1 and options.subset.max_segments > 1:
        print_bucket_distribution(
            subset_bucket, suites_missing_stats, options.stats_file
        )

    # We ignored suite groups (lists of suite paths under the same key in the tests YAML),
    # but now we must recreate them. This is because suites within a group are
    # mutually exclusive and therefore cannot run concurrently. If several
    # suites from the same group were assigned to the same bucket,
    # we recreate those here.
    grouped: dict[str, list[Any]] = {}
    for timed_suite in subset_bucket.suites:
        grouped.setdefault(timed_suite.group, []).append(timed_suite.suite)
    groups_in_bucket = list(grouped.items())

    test_file_paths = [timed_suite.suite.path for timed_suite in subset_bucket.suites]
    return GroupsSegment(options.subset, test_file_paths, groups_in_bucket)


def flatten_groups(groups: dict[str, list[Any]]) -> list[tuple[str, Any]]:
    return [(key, value) for key, values in groups.items() for value in values]


def print_bucket_distribution(
    bucket: SuiteBucket, suites_missing_stats: list[str], stats_file: str
):
    def format_bucket_duration(attr):
        duration, bottleneck = bucket.makespan_info(attr)
        if bottleneck:
            path, duration = bottleneck
            has_real_stats = path not in suites_missing_stats
            formatted_duration = format_time(duration)
            duration_str = (
                f" at {formatted_duration}"
                if has_real_stats
                else f" at (default) {formatted_duration}"
            )
            suffix = f" (bottlenecked by `{path}`{duration_str})"
        else:
            suffix = ""
        return f"{format_time(duration)}{suffix}"

    print(
        f"Bucket distribution based on `{stats_file}` (bucket-relative weights, not expected runtime):\n"
        f"  min: {format_bucket_duration('min')}\n"
        f"  p50: {format_bucket_duration('p50')}\n"
        f"  p95: {format_bucket_duration('p95')}\n"
        f"  max: {format_bucket_duration('max')}\n"
    )


def format_time(total_seconds) -> str:
    days, remainder = divmod(total_seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, seconds = divmod(remainder, 60)
    milliseconds = seconds * 1000

    parts = []
    if days > 0:
        parts.append(f"{int(days)}d")
    if hours > 0 or days > 0:
        parts.append(f"{str(int(hours)).zfill(2)}h")
    if minutes > 0 or hours > 0 or days > 0:
        parts.append(f"{str(int(minutes)).zfill(2)}m")
    if seconds >= 1 or minutes > 0 or hours > 0 or days > 0:
        parts.append(f"{str(int(seconds)).zfill(2)}s")
    if total_seconds < 1:
        parts.append(f"{str(int(milliseconds))}ms")

    return " ".join(parts)
