from robot import result, running
from robot.libraries.DateTime import Time

# This listener wraps the RetryFailed listener to gracefully skip retrying for timed-out tests.
# Failure is silenced because the lack of `RetryFailed` isn't a problem if `retry_count` is one.
try:
    from RetryFailed import RetryFailed
except:
    pass

# The name isn't CamelCase typically used for Python classes only because it
# has to match the name of the file and snake_case is used for other listeners.
class retry_and_timeout_listener:
    ROBOT_LISTENER_API_VERSION = 3

    def __init__(self, retry_count):
        if int(retry_count) > 1:
            global_retries = int(retry_count) - 1  # Our `retry_count` includes the original test too.
            self.retry_failed = RetryFailed(global_retries)

    # Redirects access to all callbacks not implemented in this listener to `RetryFailed` if it's used.
    def __getattr__(self, name):
        # This prevents infinite recursion if `self.retry_failed` wasn't initialized.
        # None is always returned cause `__getattr__` won't be called if it was initialized.
        if name == 'retry_failed':
            return None

        if self.retry_failed and hasattr(self.retry_failed, name):
            return getattr(self.retry_failed, name)

    def start_suite(self, suite: running.TestSuite, result: result.TestSuite):
        # Grab our RobotTestSuite and restore the original parent.
        (self.tests_provider, suite.parent) = suite.parent
        self.after_timeout = False

        # start_suite isn't currently used by RetryFailed but let's check for future versions.
        if self.retry_failed and hasattr(self.retry_failed, 'start_suite'):
            self.retry_failed.start_suite(suite, result)

    def end_test(self, test: running.TestCase, result: result.TestCase):
        timed_out = result.failed and result.timeout and result.timeout.timed_out()
        timeout_expected = self.tests_provider.timeout_expected_tag in test.tags
        if timeout_expected:
            # It passed if timeout occurred within the test timeout +3s.
            tolerance_seconds = 3
            over_timeout = result.elapsed_time.seconds - Time(test.timeout).seconds
            if timed_out and over_timeout < tolerance_seconds:
                result.status = result.PASS
            else:
                result.message = f"Expected timeout didn't occur in {test.timeout} (+{tolerance_seconds}s)"

        # Mark messages that failed after another test timed out except tests that timed out.
        # It isn't really probable that Renode restart will cause timeouts.
        if result.failed and self.after_timeout and not timed_out:
            result.message = result.message + '\n\n' + self.tests_provider.after_timeout_message_suffix

        if timed_out:
            # See `_create_timeout_handler` in `robot_tests_provider`, mostly restarts Renode.
            self.tests_provider.timeout_handler(test, result)
            self.after_timeout = True

            # Let's prevent retrying a test with unexpected timeout but let's still call
            # `RetryFailed.end_test` as `RetryFailed` might not properly work without it.
            if self.retry_failed and not timeout_expected:
                self.retry_failed.max_retries = self.retry_failed.retries

        if self.retry_failed:
            # `RetryFailed` changes the status of retried tests to skipped. Let's restore
            # the original status so that our output formatters print them as failed.
            original_message = result.message
            original_status = result.status
            self.retry_failed.end_test(test, result)
            result.status = original_status

            # Let's also restore the original message without suffixes added by `RetryFailed`
            # unless it contains the number of attempts required in our test reporting.
            if not self.tests_provider.retry_test_regex.search(result.message):
                result.message = original_message
