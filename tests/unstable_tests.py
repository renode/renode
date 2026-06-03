import argparse
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Iterator, Protocol, TypeVar

import yaml


def add_args(parser: argparse.ArgumentParser):
    parser.add_argument(
        "--unstable",
        dest="known_unstable_file",
        type=Path,
        nargs="?",
        default=None,
        help="Path to a file containing tests that are known to be unstable. The results of these tests are ignored and they are not retried.",
    )


@dataclass(frozen=True)
class KnownUnstableSuite:
    tests: frozenset[str] = field(default_factory=frozenset)


def parse_file(path: os.PathLike) -> dict[str, KnownUnstableSuite]:
    with open(path, "r") as f:
        data = yaml.safe_load(f)

    suites: dict[str, KnownUnstableSuite] = {}

    for entry in data:
        # Accept standalone suite paths (means all tests in suite are unstable).
        if isinstance(entry, str):
            # Ensure consistent path separators, even on Windows
            suite_path = Path(entry).as_posix()
            suites[suite_path] = KnownUnstableSuite()

        # Suite paths may contain a sub-list defining which specific test cases are unstable.
        elif isinstance(entry, dict):
            for raw_path, test_list in entry.items():
                if test_list is None:
                    raise ValueError(
                        f"Malformed YAML structure for entry '{raw_path}' in '{path}'. "
                        "Trailing colons must be followed by an indented list of test cases."
                    )

                # Ensure consistent path separators, even on Windows
                suite_path = Path(raw_path).as_posix()

                unstable_tests = frozenset(str(test) for test in test_list)
                suites[suite_path] = KnownUnstableSuite(tests=unstable_tests)

        else:
            raise ValueError(
                f"Malformed YAML structure '{entry}' in '{path}. "
                "Only standalone suite paths and suite paths with sub-lists are accepted."
            )

    return suites


def annotate_tests(
    groups: dict[str, list[Any]], known_unstable: dict[str, KnownUnstableSuite]
):
    suites = [suite for group in groups.values() for suite in group]

    for suite in suites:
        unstable_suite = known_unstable.get(suite.path)
        if unstable_suite:
            suite.known_unstable = unstable_suite


class HasName(Protocol):
    name: str


T = TypeVar("T", bound=HasName)


def filter_unstable(
    known_unstable: KnownUnstableSuite, tests: Iterable[T]
) -> Iterator[T]:
    if not known_unstable.tests:
        # If no specific test case is defined as unstable, that means all of them are.
        yield from tests
    else:
        yield from (test for test in tests if test.name in known_unstable.tests)
