*** Settings ***
Resource                            riscv-arch-tests.resource

*** Test Cases ***
Should Run Arch Tests
    Run Arch Tests Subset           4
