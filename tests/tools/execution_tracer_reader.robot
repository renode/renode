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
    [Arguments]                     ${executable}  ${compress}

    Create Platform                 ${executable}

    ${trace_file}=                  Allocate Temporary File

    Execute Command                 ${TRACED_CPU} CreateExecutionTracing "trace" @${trace_file} PC true ${compress}
    Execute Command                 emulation RunFor "0.017"
    Execute Command                 ${TRACED_CPU} DisableExecutionTracing
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

Trace And Report Coverage
    [Arguments]                     ${compress}=False
    ${coverage_file}=               Allocate Temporary File
    ${binary_file}=                 Download File  ${COVERAGE_TEST_BINARY_URL}
    ${code_file}=                   Download File And Rename  ${COVERAGE_TEST_CODE_URL}  ${COVERAGE_TEST_CODE_FILENAME}

    ${trace}=                       Trace Execution  ${COVERAGE_TEST_BINARY_URL}  ${compress}
    ${script_args}=                 Create List
    ...                             --coverage
    ...                             ${binary_file}
    ...                             --coverage-code
    ...                             ${code_file}
    ...                             --coverage-output
    ...                             ${coverage_file}
    IF  ${compress} == True
        Append To List                  ${script_args}  -d
    END
    Append To List                  ${script_args}  ${trace}
    Execute Python Script           ${EXECUTION_TRACER}  ${script_args}

    ${coverage_report_content}=     Get File  ${coverage_file}
    ${coverage_report}=             Split To Lines  ${coverage_report_content}
    Should Report Proper Coverage   ${coverage_report}  ${COVERAGE_REPORT_LINES}

*** Test Cases ***
Trace And Report Coverage
    Trace And Report Coverage

Trace With Compressed Output And Report Coverage
    Trace And Report Coverage       True
