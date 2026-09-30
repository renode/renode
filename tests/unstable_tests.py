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


def parse_file(yaml_path: os.PathLike) -> dict[str, KnownUnstableSuite]:
    with open(yaml_path, "r") as f:
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
            for raw_suite_path, configuration in entry.items():
                # Ensure consistent path separators, even on Windows
                suite_path = Path(raw_suite_path).as_posix()
                suites[suite_path] = _parse_suite(configuration, raw_suite_path, yaml_path)

        else:
            raise ValueError(
                f"Malformed YAML structure '{entry}' in '{yaml_path}'. "
                "Only standalone suite paths and suite paths with sub-lists are accepted."
            )

    return suites


def _parse_suite(
    configuration: Any, suite_path: str, yaml_path: os.PathLike
) -> KnownUnstableSuite:
    if configuration is None:
        raise ValueError(
            f"Malformed YAML structure for entry '{suite_path}' in '{yaml_path}'. "
            "Trailing colons must be followed by an indented list of test cases."
        )

    unstable_tests = frozenset(str(test) for test in configuration)
    return KnownUnstableSuite(tests=unstable_tests)


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
