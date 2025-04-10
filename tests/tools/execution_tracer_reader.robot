*** Variables ***
${COVERAGE_TEST_BINARY_URL}         https://dl.antmicro.com/projects/renode/coverage-tests/coverage-test.elf-s_3603888-0f7cfe992528c2576a9ac6a4dcc3a41b03d1d6eb
${COVERAGE_TEST_CODE_URL}           https://dl.antmicro.com/projects/renode/coverage-tests/main.c
${COVERAGE_TEST_CODE_FILENAME}      main.c
${EXECUTION_TRACER}                 ${RENODETOOLS}/execution_tracer/execution_tracer_reader.py
${TRACED_CPU}                       cpu1
&{COVERAGE_REPORT_LINES}            # pairs of line number and expected executions
...                                 6=28
...                                 7=2828
...                                 8=2800
...                                 10=28
...                                 12=32
...                                 13=3232
...                                 14=3200
...                                 16=32
...                                 18=2
...                                 19=202
...                                 20=200
...                                 22=2
...                                 24=1
...                                 25=1
...                                 26=101
...                                 27=100
...                                 30=1
...                                 32=101
...                                 33=100
...                                 34=32
...                                 36=100
...                                 37=28
...                                 41=1
...                                 43=1
...                                 44=1

@{COVERAGE_REPORT_LCOV}
...                                 TN:
...                                 SF:main.c
...                                 DA:6,28
...                                 DA:7,2828
...                                 DA:8,2800
...                                 DA:10,28
...                                 DA:12,32
...                                 DA:13,3232
...                                 DA:14,3200
...                                 DA:16,32
...                                 DA:18,2
...                                 DA:19,202
...                                 DA:20,200
...                                 DA:22,2
...                                 DA:24,1
...                                 DA:25,1
...                                 DA:26,101
...                                 DA:27,100
...                                 DA:30,1
...                                 DA:32,101
...                                 DA:33,100
...                                 DA:34,32
...                                 DA:36,100
...                                 DA:37,28
...                                 DA:41,1
...                                 DA:43,1
...                                 DA:44,1
...                                 end_of_record

*** Keywords ***
Execute Python Script
    [Arguments]                     ${path}  ${args}
    ${all_args}=                    Create List  ${path}  @{args}

    ${output}=                      Evaluate  subprocess.run([sys.executable] + ${all_args})  sys,subprocess
    RETURN                          ${output}

Download File And Rename
    [Arguments]                     ${url}  ${filename}
    ${temporary_file}=              Download File  ${url}
    ${path_fragments}=              Split Path  ${temporary_file}
    ${new_path}=                    Join Path  ${path_fragments}[0]  ${filename}
    Move File                       ${temporary_file}  ${new_path}
    RETURN                          ${new_path}

Create Platform
    [Arguments]                     ${executable}
    Execute Command                 $bin=@${executable}
    Execute Command                 i @scripts/single-node/kendryte_k210.resc
    Execute Command                 cpu2 IsHalted true

Trace Execution
    [Arguments]                     ${cpu}  ${mode}  ${compress}

    ${trace_file}=                  Allocate Temporary File

    Execute Command                 ${cpu} CreateExecutionTracing "trace" @${trace_file} ${mode} true ${compress}
    Execute Command                 emulation RunFor "0.017"
    Execute Command                 ${cpu} DisableExecutionTracing
    RETURN                          ${trace_file}

Line Should Report Executions
    [Arguments]                     ${line}  ${executions}
    Should Start With               ${line}  ${executions}:  strip_spaces=True  collapse_spaces=True

Should Report Proper Coverage
    [Arguments]                     ${report}  ${expected_lines}
    FOR  ${expected_line}  IN  &{expected_lines}
        ${line_index}=                  Evaluate  ${expected_line}[0] - 1
        Line Should Report Executions   ${report}[${line_index}]  ${expected_line}[1]
    END

    FOR  ${line_index}  ${report_line}  IN ENUMERATE  @{report}
        ${line_number}=                 Evaluate  str(${line_index} + 1)
        IF  ${{ $line_number not in $COVERAGE_REPORT_LINES }}
            Line Should Report Executions   ${report_line}  0
        END
    END

Should Report Proper Coverage LCOV
    [Arguments]                     ${report}  ${expected_lines}
    Should Be Equal As Strings      ${report}  ${expected_lines}  strip_spaces=True

Trace And Report Coverage
    [Arguments]                     ${is_legacy}  ${compress}=False
    ${coverage_file}=               Allocate Temporary File
    ${binary_file}=                 Download File  ${COVERAGE_TEST_BINARY_URL}
    ${code_file}=                   Download File And Rename  ${COVERAGE_TEST_CODE_URL}  ${COVERAGE_TEST_CODE_FILENAME}

    Create Platform                 ${COVERAGE_TEST_BINARY_URL}

    ${trace}=                       Trace Execution  ${TRACED_CPU}  PC  ${compress}
    ${script_args}=                 Create List

    IF  ${compress} == True
        Append To List                  ${script_args}  --decompress
    END

    Append To List                  ${script_args}
    ...                             coverage
    ...                             ${trace}
    ...                             --binary
    ...                             ${binary_file}
    ...                             --sources
    ...                             ${code_file}
    ...                             --output
    ...                             ${coverage_file}

    IF  ${is_legacy} == True
        Append To List              ${script_args}  --legacy
    END

    Execute Python Script           ${EXECUTION_TRACER}  ${script_args}

    ${coverage_report_content}=     Get File  ${coverage_file}
    ${coverage_report}=             Split To Lines  ${coverage_report_content}
    IF  ${is_legacy} == True
        Should Report Proper Coverage       ${coverage_report}  ${COVERAGE_REPORT_LINES}
    ELSE
        # The slice is necessary to omit "filename", which is expected to differ (since the absolute paths are never the same in the temp directory)
        Should Report Proper Coverage LCOV  ${coverage_report}[2:]  ${COVERAGE_REPORT_LCOV}[2:]
    END

*** Test Cases ***
Trace And Report Coverage
    Trace And Report Coverage       False

Trace And Report Coverage In Legacy Format
    Trace And Report Coverage       True

Trace With Compressed Output And Report Coverage
    Trace And Report Coverage       False  True

Trace With Compressed Output And Report Coverage In Legacy Format
    Trace And Report Coverage       True  True
