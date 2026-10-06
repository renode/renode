from robot import result, running

from tests_engine import TestTag


def keyword_states(test: running.TestCase, keyword_name: str) -> list[str]:
    """Return the states passed to `keyword_name`, such as `Provides` or `Requires`, in the test's body.

    Only keywords called directly in the body count, like in `RobotTestSuite._get_dependencies`.
    """

    def _state_name(argument: str) -> str:
        # Return `<name>` both for a named `state=<name>` argument and for a positional `<name>` one.
        before, _, after = argument.partition("=")
        return after or before

    return [
        _state_name(step.args[0])
        for step in test.body
        if isinstance(step, running.Keyword) and step.name == keyword_name
    ]


class StateDependencyListener:
    """Skip tests whose state from `Requires` comes from a test that didn't pass.

    A test that failed or was skipped may not have provided its state, so tests that
    require it would only fail because the state is missing.
    """

    ROBOT_LISTENER_API_VERSION: int = 3

    def __init__(self, missing_state_reasons: dict[str, str]) -> None:
        # Maps states to why their providers didn't provide them. The caller owns
        # the map so that it outlives this listener when a provider and its dependents run
        # in separate suite runs.
        # This happens when `--fixture` selects only the dependent, as its providers then
        # run in their own suite run first.
        self.missing_state_reasons: dict[str, str] = missing_state_reasons

    def start_test(self, test: running.TestCase, _test_result: result.TestCase) -> None:
        required = keyword_states(test, "Requires")
        if not required:
            return

        # A test has at most one `Requires`, as each one resets the emulation.
        assert len(required) == 1, f"'{test.name}' has more than one `Requires`."
        state = required[0]
        if state not in self.missing_state_reasons:
            return

        # The required state is missing, so this test should be skipped.
        reason = self.missing_state_reasons[state]

        # Tests further down the dependency chain should be skipped with the same reason.
        for provided_state in keyword_states(test, "Provides"):
            self.missing_state_reasons[provided_state] = reason

        test.config(setup=None, teardown=None)
        test.body.clear()
        test.body.create_keyword("Skip", [f"Required state '{state}' wasn't provided because {reason}."])

    def end_test(self, test: running.TestCase, test_result: result.TestCase) -> None:
        provided = keyword_states(test, "Provides")
        if not provided:
            return

        # A retried attempt is marked SKIP, but the test runs again and may still provide its state.
        if TestTag.RETRIED_ATTEMPT in test_result.tags:
            return

        if test_result.passed:
            # The test provided its states, so clear them if an earlier suite retry or iteration marked them missing.
            for state in provided:
                self.missing_state_reasons.pop(state, None)
            return

        # Known-unstable tests only reach SKIP by failing, unless they were skipped explicitly.
        if TestTag.UNSTABLE in test_result.tags and "robot:skip" not in test_result.tags:
            reason = f"the known-unstable test '{test.name}' failed"
        elif test_result.failed:
            reason = f"'{test.name}' failed"
        else:
            reason = f"'{test.name}' was skipped"

        # The test may have stopped before its `Provides`, so its states should count as missing.
        for state in provided:
            self.missing_state_reasons[state] = reason
