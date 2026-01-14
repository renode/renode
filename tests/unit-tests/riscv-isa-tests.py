import os

def get_variables(arg):
    rv32_tests = []
    rv64_tests = []
    if os.path.isdir(arg):
        all_files = os.listdir(arg)
        rv32_tests = list(filter(lambda t: t.startswith("rv32") and not t.endswith(".dump"), all_files))
        rv64_tests = list(filter(lambda t: t.startswith("rv64") and not t.endswith(".dump"), all_files))

    return {
        "TESTS_32": rv32_tests,
        "TESTS_64": rv64_tests,
    }
