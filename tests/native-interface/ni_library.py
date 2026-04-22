import xmlrpc.client
from xmlrpc.client import ServerProxy


class ni_library:
    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self):
        self._proxy: ServerProxy | None = None

    def _run(self, keyword: str, *args: object) -> object:
        assert self._proxy is not None

        result: dict[str, object] = self._proxy.run_keyword(keyword, list(args))  # type: ignore
        if result.get("status") == "FAIL":
            raise AssertionError(result.get("error", f"{keyword} failed"))

        return result.get("return", "")

    def connect(self, port):
        self._proxy = xmlrpc.client.ServerProxy(f"http://127.0.0.1:{port}/")
        # Test the connection by fetching keyword names
        self._proxy.get_keyword_names()

    def execute_command(self, command):
        return self._run("ExecuteCommand", command)

    def create_terminal_tester(self, peripheral):
        return self._run("CreateTerminalTester", peripheral)

    def write_char_on_uart(self, char):
        return self._run("WriteCharOnUart", char)

    def wait_for_prompt_on_uart(self, prompt):
        return self._run("WaitForPromptOnUart", prompt)
