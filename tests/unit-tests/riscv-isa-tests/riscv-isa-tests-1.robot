*** Settings ***
Resource                            riscv-isa-tests.resource

*** Test Cases ***
Should Run ISA Tests
    Run Tests Subset                1
