*** Variables ***
@{IGNORED_TESTS}
# Aborting machine
...                                 rv64uzbb-v-maxu
...                                 rv64uzbb-p-maxu
...                                 rv64uzbb-v-minu
...                                 rv64uzbb-p-minu
...                                 rv64mi-p-breakpoint
...                                 rv32mi-p-breakpoint
# Failures
...                                 rv64uzabha-p-amomax_b
...                                 rv64uzabha-p-amomax_h
...                                 rv64uzabha-p-amoxor_b
...                                 rv32uzbkx-p-xperm8
...                                 rv32uzbkb-v-unzip
...                                 rv32uzbkb-p-unzip
...                                 rv32uzabha-p-amoor_b
...                                 rv32uzabha-v-amoor_h
...                                 rv64ud-v-move
...                                 rv32uzabha-p-amoor_h
...                                 rv32uzabha-p-amoswap_b
...                                 rv64uzabha_zacas-p-amocas_b
...                                 rv64uzabha-p-amoor_b
...                                 rv64uzbkb-p-packw
...                                 rv32uzabha-p-amoxor_h
...                                 rv32uzabha-p-amoand_b
...                                 rv32uzabha-v-amoswap_b
...                                 rv32uzabha-v-amomaxu_b
...                                 rv64uzbkb-p-brev8
...                                 rv32uzabha-p-amoand_h
...                                 rv64uzabha-p-amoadd_b
...                                 rv32uzabha-p-amomaxu_b
...                                 rv32mi-p-ma_fetch
...                                 rv64uzabha-p-amomin_h
...                                 rv32uzabha-v-amoand_h
...                                 rv32uzabha-p-amomax_b
...                                 rv32uzbkb-v-zip
...                                 rv64uzabha-p-amoor_h
...                                 rv32uzbkx-v-xperm4
...                                 rv32ud-v-fclass
...                                 rv64uzabha-p-amominu_h
...                                 rv32uzabha_zacas-v-amocas_b
...                                 rv64uzbkb-v-packh
...                                 rv64ui-p-ma_data
...                                 rv32si-p-dirty
...                                 rv64uzabha-p-amomin_b
...                                 rv64ud-p-move
...                                 rv64mi-p-ma_fetch
...                                 rv64uzabha-p-amomaxu_b
...                                 rv32uzbkx-p-xperm4
...                                 rv32uzabha-v-amoadd_b
...                                 rv32uzbkb-p-brev8
...                                 rv64uzabha-p-amoand_h
...                                 rv32uzabha_zacas-p-amocas_h
...                                 rv32uzabha-p-amomin_h
...                                 rv64uzabha-p-amoswap_h
...                                 rv64si-p-dirty
...                                 rv64uzbkx-p-xperm4
...                                 rv32uzabha-p-amomax_h
...                                 rv32uzabha-p-amoadd_h
...                                 rv32uzabha-p-amomaxu_h
...                                 rv32uzbkx-v-xperm8
...                                 rv32uzabha-v-amominu_h
...                                 rv32uzabha-v-amomin_h
...                                 rv64si-p-csr
...                                 rv32uzabha-v-amomax_h
...                                 rv64uzabha-p-amomaxu_h
...                                 rv64uzbkb-v-pack
...                                 rv32uzabha-p-amominu_h
...                                 rv64uzbkb-p-pack
...                                 rv32uzabha_zacas-v-amocas_h
...                                 rv32uzbkb-p-packh
...                                 rv32uzbkb-v-pack
...                                 rv32uzabha-v-amomaxu_h
...                                 rv64uzbkx-p-xperm8
...                                 rv32uzabha-v-amoor_b
...                                 rv32ud-p-fclass
...                                 rv32uzabha-v-amoand_b
...                                 rv64mi-p-instret_overflow
...                                 rv32uzabha-v-amoxor_b
...                                 rv32uzabha-v-amoxor_h
...                                 rv32uzabha-p-amoxor_b
...                                 rv32uzabha-v-amoadd_h
...                                 rv64uzabha-p-amoand_b
...                                 rv32uzbkb-v-packh
...                                 rv32uzabha-v-amominu_b
...                                 rv32uzabha-v-amomax_b
...                                 rv32uzbkb-p-pack
...                                 rv64uzbkb-v-brev8
...                                 rv64uzabha-p-amoswap_b
...                                 rv64uzabha-p-amominu_b
...                                 rv32uzabha-p-amomin_b
...                                 rv32ui-p-ma_data
...                                 rv32uzbkb-p-zip
...                                 rv64mzicbo-p-zero
...                                 rv64uzabha-p-amoxor_h
...                                 rv64uzbkb-v-packw
...                                 rv64mi-p-csr
...                                 rv32uzabha-p-amominu_b
...                                 rv64uzacas-p-amocas_w
...                                 rv64uzbkb-p-packh
...                                 rv64uzabha_zacas-p-amocas_h
...                                 rv32mi-p-instret_overflow
...                                 rv32uzabha_zacas-p-amocas_b
...                                 rv64uzacas-v-amocas_w
...                                 rv32uzabha-p-amoswap_h
...                                 rv32uzabha-p-amoadd_b
...                                 rv64uzabha-p-amoadd_h
...                                 rv32uzabha-v-amomin_b
...                                 rv64ui-v-ma_data
...                                 rv32ui-v-ma_data
...                                 rv32uzabha-v-amoswap_h
...                                 rv32uzbkb-v-brev8
...                                 rv64mi-p-illegal
...                                 rv32mi-p-illegal
...                                 rv64uzabha-v-amoswap_b
...                                 rv64uzabha-v-amoswap_h
...                                 rv64uzabha-v-amomaxu_b
...                                 rv64uzabha-v-amomaxu_h
...                                 rv64uzabha-v-amominu_b
...                                 rv64uzabha-v-amominu_h
...                                 rv64uzbkx-v-xperm8
...                                 rv64uzbkx-v-xperm4
...                                 rv64uzabha-v-amomin_b
...                                 rv64uzabha-v-amomin_h
...                                 rv64uzabha-v-amoor_b
...                                 rv64uzabha-v-amoor_h
...                                 rv64uzabha-v-amoand_b
...                                 rv64uzabha-v-amoand_h
...                                 rv64uzabha-v-amomax_b
...                                 rv64uzabha-v-amomax_h
...                                 rv64uzabha_zacas-v-amocas_b
...                                 rv64uzabha_zacas-v-amocas_h
...                                 rv64uzabha-v-amoxor_b
...                                 rv64uzabha-v-amoxor_h
...                                 rv64uzabha-v-amoadd_b
...                                 rv64uzabha-v-amoadd_h

# https://github.com/riscv-software-src/riscv-tests/commit/3df703cd52d5f0d8224e3c50bf03c6cb70efff98
${TEST_ARCHIVE}                     https://dl.antmicro.com/projects/renode/riscv-tests-binaries.tar.gz-s_1433600-220b878b4ae3aaffd36e0b228e5185474dfa65ec

*** Keywords ***
Run Test Case
    [Arguments]                     ${test}  ${width}
    # Fail individual unit-tests with binary name attached to failure
    ${status}                       ${error}=  Run Keyword And Ignore Error  Run Test Case Inner  ${test}  ${width}
    IF  $status == 'FAIL'
        ${dirname}                      ${filename}=  Split Path  ${test}
        Run Keyword And Continue On Failure  Fail  ${filename}
    END

Run Test Case Inner
    [Arguments]                     ${test}  ${width}

    Execute Command                 Clear
    Execute Command                 include "${CURDIR}/ArrayMemoryRiscVTestWatcher.cs"

    Execute Command                 log "${test}" 1
    Create Log Tester               1
    Execute Command                 $bin=@${test}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """cpu: CPU.RiscV${width} @ sysbus { cpuType: "rv${width}gcv_zba_zbb_zbc_zbs_zfh_zacas_smepmp_zicond_zicsr" }"""
    Execute Command                 machine LoadPlatformDescriptionFromString """mem: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x100000 }"""
    Execute Command                 machine LoadPlatformDescriptionFromString """trapmem: Memory.ArrayMemory @ sysbus 0x1000 { size: 0x100000 }"""
    Execute Command                 cpu AssembleBlock 0x1010 "j ."
    Execute Command                 sysbus LoadELF $bin
    ${tohost}=                      Execute Command  sysbus GetSymbolAddress "tohost"
    # tohost section is aligned to 0x1000 https://github.com/riscv/riscv-test-env/blob/6de71edb142be36319e380ce782c3d1830c65d68/p/link.ld#L8-L9
    Execute Command                 machine LoadPlatformDescriptionFromString """tohost: Memory.ArrayMemoryRiscVTestWatcher @ sysbus new Bus.BusPointRegistration { address: ${tohost}; cpu: cpu } { size: 0x1000 }"""

    Should Not Be In Log            CPU abort  timeout=0.001
    Wait For Log Entry              TEST FINISHED  timeout=0
    ${res}=                         Execute Command  tohost ExitCode
    Should Contain                  ${res}  0x0000000000000000

*** Test Cases ***
Should Run Tests
    [Tags]                          exclude_osx

    ${archive}=                     Download File  ${TEST_ARCHIVE}
    ${binariesDirectory}=           AllocateTemporaryDirectory  elfs
    Untar File                      ${archive}  ${binariesDirectory}
    ${binaries}=                    List Files In Directory Recursively  ${binariesDirectory}  rv*

    FOR  ${test}  IN  @{binaries}
        ${dirname}                      ${filename}=  Split Path  ${test}

        Continue For Loop If            $filename in $IGNORED_TESTS

        IF  "rv32" in $filename
            Run Test Case                   ${test}  32
        ELSE IF  "rv64" in $filename
            Run Test Case                   ${test}  64
        ELSE
            Fail                            "${test} not categorized"
        END
    END
