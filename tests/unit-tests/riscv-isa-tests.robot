#
# This test suite is used to run isa tests from https://github.com/riscv-software-src/riscv-tests.
# The path to the directory with compiled tests can be passed from the command line
# or specified via an RISCV_TESTS_PATH environment variable (it defaults to /riscv-tests/isa).
# Both invocations below are supported:
#   renode-test riscv-isa-tests.robot --variable RISCV_TESTS_PATH:<absolute path to a directory with compiled isa tests>
#   RISCV_TESTS_PATH=<absolute path to a directory with compiled isa tests> renode-test riscv-isa-tests.robot
# For example, build tests with commands:
#   ./configure --prefix=$RISCV/target
#   make
#   make install
# And set environment variable RISCV_TESTS_PATH=$RISCV/target/share/riscv-tests/isa.
# The available tests will be detected automatically by riscv-isa-tests.py.
# If no tests are detected (i.e. directory doesn't exist), there are no failures and test suite passes.
#

*** Settings ***
Variables    riscv-isa-tests.py  ${RISCV_TESTS_PATH}

*** Variables ***
${RISCV_TESTS_PATH}              %{RISCV_TESTS_PATH=/riscv-tests/isa}

*** Keywords ***
Run Test Case
    [Arguments]     ${test}     ${width}

    Execute Command                 Clear
    Execute Command                 include "${CURDIR}/ArrayMemoryRiscVTestWatcher.cs"

    Execute Command                 log "${test}" 1
    Create Log Tester               1
    Execute Command                 $bin=@${RISCV_TESTS_PATH}/${test}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """cpu: CPU.RiscV${width} @ sysbus { cpuType: "rv${width}gcv_zba_zbb_zbc_zbs_zfh_zacas_smepmp" }"""
    Execute Command                 machine LoadPlatformDescriptionFromString """mem: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x100000 }"""
    Execute Command                 sysbus LoadELF $bin
    ${tohost}=     Execute Command  sysbus GetSymbolAddress "tohost"
    # tohost section is aligned to 0x1000 https://github.com/riscv/riscv-test-env/blob/6de71edb142be36319e380ce782c3d1830c65d68/p/link.ld#L8-L9
    Execute Command                 machine LoadPlatformDescriptionFromString """tohost: Memory.ArrayMemoryRiscVTestWatcher @ sysbus new Bus.BusPointRegistration { address: ${tohost}; cpu: cpu } { size: 0x1000 }"""

    Should Not Be In Log            CPU abort  timeout=0.001
    Wait For Log Entry              TEST FINISHED  timeout=0
    ${res}=  Execute Command        tohost ExitCode
    Should Contain                  ${res}      0x0000000000000000

*** Test Cases ***
Should Run Tests 32
    [Tags]                          basic-tests
    [Template]    Run Test Case

    FOR  ${test}  IN  @{TESTS_32}
        ${test}   32
    END

Should Run Tests 64
    [Tags]                          basic-tests
    [Template]    Run Test Case

    FOR  ${test}  IN  @{TESTS_64}
        ${test}   64
    END
