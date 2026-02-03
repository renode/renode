#
# This test suite is used to run arch tests from https://github.com/riscv-non-isa/riscv-arch-test.
# At the time of writing, it was used with https://github.com/riscv-non-isa/riscv-arch-test/commit/1dfa48c2adecaa16fae9fca14d34c591ea99321c.
# The path to the directory with compiled tests can be passed from the command line
# or specified via an RISCV_ARCH_TESTS_PATH environment variable (it defaults to /riscv-arch-test/work/).
# Both invocations below are supported:
#   renode-test riscv-arch-tests.robot --variable RISCV_ARCH_TESTS_PATH:<absolute path to a directory with compiled arch tests>
#   RISCV_ARCH_TESTS_PATH=<absolute path to a directory with compiled arch tests> renode-test riscv-arch-tests.robot
# Build tests based on https://github.com/riscv-non-isa/riscv-arch-test/commit/1dfa48c2adecaa16fae9fca14d34c591ea99321c.
# The available tests will be detected automatically by riscv-arch-tests.py.
# If no tests are detected (i.e. directory doesn't exist), there are no failures and test suite passes.
#

*** Settings ***
Variables    riscv-arch-tests.py  ${RISCV_ARCH_TESTS_PATH}

*** Variables ***
${RISCV_ARCH_TESTS_PATH}         %{RISCV_ARCH_TESTS_PATH=/riscv-arch-test/work/}

*** Keywords ***
Run Test Case
    [Arguments]     ${test}     ${width}

    Execute Command                 Clear
    Execute Command                 include "${CURDIR}/ArrayMemoryRiscVTestWatcher.cs"

    Execute Command                 log "${test}" 1
    Create Log Tester               1
    Execute Command                 $bin=@${test}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """cpu: CPU.RiscV${width} @ sysbus { cpuType: "rv${width}gcv_zba_zbb_zbc_zbs_zfh_zacas_smepmp" }"""
    Execute Command                 machine LoadPlatformDescriptionFromString """uart: UART.NS16550 @ sysbus 0x10000000"""
    Execute Command                 machine LoadPlatformDescriptionFromString """mem: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x100000 }"""
    Execute Command                 showAnalyzer uart
    Execute Command                 sysbus LoadELF $bin
    ${tohost}=     Execute Command  sysbus GetSymbolAddress "tohost"
    # tohost section is aligned to 0x1000 https://github.com/riscv/riscv-test-env/blob/6de71edb142be36319e380ce782c3d1830c65d68/p/link.ld#L8-L9
    Execute Command                 machine LoadPlatformDescriptionFromString """tohost: Memory.ArrayMemoryRiscVTestWatcher @ sysbus new Bus.BusPointRegistration { address: ${tohost}; cpu: cpu } { size: 0x1000 }"""

    Should Not Be In Log            CPU abort  timeout=0.001
    Wait For Log Entry              TEST FINISHED  timeout=0
    ${res}=  Execute Command        tohost ExitCode
    Should Contain                  ${res}      0x0000000000000000

*** Test Cases ***
Should Run Arch Tests 32
    [Tags]                          basic-tests
    [Template]    Run Test Case

    FOR  ${test}  IN  @{TESTS_ARCH_32}
        ${test}   32
    END

Should Run Arch Tests 64
    [Tags]                          basic-tests
    [Template]    Run Test Case

    FOR  ${test}  IN  @{TESTS_ARCH_64}
        ${test}   64
    END
