import os


def list_files_recursively(path):
    files = []
    with os.scandir(path) as entries:
        for entry in entries:
            if entry.is_file():
                files.append(entry.path)
            elif entry.is_dir():
                files = files + list_files_recursively(entry.path)

    return files


def get_variables(arg):
    rv32_arch_tests = []
    rv64_arch_tests = []

    if os.path.isdir(arg):
        all_files = list_files_recursively(arg)
        rv32_arch_tests = list(
            filter(lambda t: t.endswith(".elf") and "spike-rv32-max" in t, all_files)
        )
        rv64_arch_tests = list(
            filter(lambda t: t.endswith(".elf") and "spike-rv64-max" in t, all_files)
        )

    return {
        "TESTS_ARCH_32": rv32_arch_tests,
        "TESTS_ARCH_64": rv64_arch_tests,
    }
