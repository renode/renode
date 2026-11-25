*** Settings ***
Resource                            riscv-isa-tests.resource

*** Test Cases ***
Should Run Arch Tests
    Run Tests Subset                2
