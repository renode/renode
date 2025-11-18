*** Settings ***
Library                             String
Library                             Collections
Library                             Process

*** Variables ***
${CACHE_TESTBENCH}                  ${RENODETOOLS}/guest_cache/src/cache_testbench.py
${GUEST_CACHE_ANALYZER}             ${RENODETOOLS}/guest_cache/src/renode_cache_interface.py
${EXPECTED_OUTPUT}                  {"l1i,u74": {"hit": 13, "miss": 1, "invalidations": 0}, "l1d,u74": {"hit": 2, "miss": 4, "invalidations": 0}}
${PLATFORM_REPL}                    platforms/cpus/sifive-fu740.repl
${CPU}                              sysbus.u74_1
${ASSEMBLY}                         SEPARATOR=\n
...                                 """
...                                 // U74 has 4-way cache with a line size of 64 bytes.
...                                 la t0, arr
...
...                                 li t1, 1
...                                 sw t1, 0(t0)    // Miss
...
...                                 li t1, 2
...                                 sw t1, 256(t0)  // Miss
...
...                                 li t1, 3
...                                 sw t1, 512(t0)  // Miss
...
...                                 li t1, 3
...                                 sw t1, 1024(t0) // Miss
...
...                                 li t1, 3
...                                 sw t1, 512(t0)  // Hit
...
...                                 li t1, 3
...                                 sw t1, 1024(t0) // Hit
...
...                                 arr:
...                                 """

*** Keywords ***
Execute Python Script
    [Arguments]                     ${path}  ${args}  ${outputPath}=${None}
    ${all_args}=                    Create List  ${path}  @{args}

    IF  $outputPath
        ${out}=                         Evaluate  open($outputPath, "w")
    ELSE
        ${out}=                         Set Variable  ${None}
    END

    Evaluate                        subprocess.run([sys.executable] + ${all_args}, stdout=$out)  sys,subprocess

    IF  $out
        Evaluate                        $out.close()
    END

Prepare Machine
    [Arguments]                     ${trace_file}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM_REPL}
    Execute Command                 sysbus.s7 IsHalted true
    Execute Command                 sysbus.u74_2 IsHalted true
    Execute Command                 sysbus.u74_3 IsHalted true
    Execute Command                 sysbus.u74_4 IsHalted true
    Execute Command                 ${CPU} PC 0x80000000
    ${size}=                        Execute Command  ${CPU} AssembleBlock `${CPU} PC` ${ASSEMBLY}
    Execute Command                 ${CPU} AddHook 0x8000002c "self.IsHalted=True"
    Execute Command                 ${CPU} MaximumBlockSize 1
    Execute Command                 ${CPU} CreateExecutionTracing "tracer" @${trace_file} PCAndOpcode
    Execute Command                 tracer TrackMemoryAccesses

*** Test Cases ***
Should Pass Selftest
    ${output_file}=                 Allocate Temporary File
    Remove File                     ${output_file}
    ${args}=                        Create List
    Execute Python Script           ${CACHE_TESTBENCH}  ${args}  outputPath=${output_file}
    ${testbench_file}=              Get File  ${output_file}
    ${testbench_results}=           Split To Lines  ${testbench_file}

    List Should Contain Value       ${testbench_results}  Fully associative cache test success!
    List Should Contain Value       ${testbench_results}  Set associative cache test success!
    List Should Contain Value       ${testbench_results}  Direct mapped cache test success!
    List Should Contain Value       ${testbench_results}  FIFO cache test success!
    List Should Contain Value       ${testbench_results}  LFU cache test success!
    List Should Contain Value       ${testbench_results}  LRU cache test success!
    Remove File                     ${output_file}

Should Analyze Cache
    ${trace_file}=                  Allocate Temporary File
    ${analyzer_file}=               Allocate Temporary File
    Prepare Machine                 ${trace_file}
    Start Emulation

    ${args}=                        Create List
    Append To List                  ${args}
    ...                             --output
    ...                             ${analyzer_file}
    ...                             ${trace_file}
    ...                             presets
    ...                             fu740.u74
    Execute Python Script           ${GUEST_CACHE_ANALYZER}  ${args}

    ${analyzer_output}=             Get File  ${analyzer_file}
    Log To Console                  ${analyzer_output}
    Should Be Equal                 ${analyzer_output}  ${EXPECTED_OUTPUT}
