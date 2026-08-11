*** Variables ***
${START_ADDRESS}                    0x100

*** Keywords ***
Create Flow Log
    ${FLOW}=                        Create List
    Set Test Variable               @{FLOW}

Fail With Flow Log
    [Arguments]                     ${error}

    ${flow_lines}=                  Create List  ${error}  ${EMPTY}  Failed with the following flow:
    FOR  ${index}  ${message}  IN ENUMERATE  @{FLOW}
        Append To List                  ${flow_lines}  ${index}: ${message}
    END
    ${flow_text}=                   CATENATE  SEPARATOR=\n  @{flow_lines}

    Fail                            ${flow_text}

Create Machine
    [Arguments]                     ${is_cortex_m}=${True}

    Execute Command                 mach create
    IF  ${is_cortex_m}
        Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas-r7fa8m1a.repl
    ELSE
        Execute Command                 machine LoadPlatformDescription @platforms/cpus/a20.repl
    END

    # Set reset handler address. Cortex-M reset vectors include the Thumb bit.
    Execute Command                 sysbus WriteDoubleWord 0x4 ${{0x100 | int($is_cortex_m)}}
    # Create simple loop in the reset handler
    ${check_address}=               Execute Command  cpu AssembleBlock 0x100 "nop; nop;"
    ${check_address}=               Evaluate  ${START_ADDRESS}+${check_address}
    Execute Command                 cpu AssembleBlock ${check_address} "nop; jump: nop; b jump;"

    Execute Command                 cpu AddHook ${check_address} "cpu.Log(LogLevel.Info, 'PC moved');"
    Create Log Tester               1

    # Reset macro is supposed to execute before cpu is resumed. The sleep here is to extend macro time and check if cpu doesn't start before it.
    Execute Command                 macro reset """ sleep 0.5; log "Machine resetting" """

Start Test
    [Arguments]                     ${is_cortex_m}=${True}

    Create Flow Log
    Reset Emulation
    Create Machine                  ${is_cortex_m}
    Execute Command                 machine SetAdvanceImmediately true
    Start Emulation
    Wait for PC to Move

Start Emulation
    Append To List                  ${FLOW}  emulation started
    Execute Command                 start

Pause CPU
    Append To List                  ${FLOW}  cpu paused
    Execute Command                 cpu Pause

Resume CPU
    Append To List                  ${FLOW}  cpu resumed
    Execute Command                 cpu Resume

Halt CPU
    Append To List                  ${FLOW}  cpu halted
    Execute Command                 cpu IsHalted true

Unhalt CPU
    Append To List                  ${FLOW}  cpu unhalted
    Execute Command                 cpu IsHalted false

CPU Should ${should_text:(Not Be|Be)} Paused
    ${should}=                      Set Variable If  "${should_text}"=="Be"  True  False

    ${is}=                          Execute Command  cpu IsPaused

    Should Be Equal                 ${should}  ${is[0:-2]}  CPU Should ${should_text} Paused

CPU Should ${should_text:(Not Be|Be)} Halted
    ${should}=                      Set Variable If  "${should_text}"=="Be"  True  False

    ${is}=                          Execute Command  cpu IsHalted

    Should Be Equal                 ${should}  ${is[0:-2]}  CPU Should ${should_text} Halted

Time ${should_text:(Should|Should Not)} Flow
    ${should_flow}=                 Set Variable If  "${should_text}"=="Should"  True  False
    ${time_a}=                      Execute Command  python "print(self.Machine.LocalTimeSource.ElapsedVirtualTime)"
    Sleep                           0.1
    ${time_b}=                      Execute Command  python "print(self.Machine.LocalTimeSource.ElapsedVirtualTime)"

    IF  ${should_flow}
        Should Not Be Equal             ${time_a}  ${time_b}  Time ${should_text} Flow
    ELSE
        Should Be Equal                 ${time_a}  ${time_b}  Time ${should_text} Flow
    END

Wait for PC to Move
    Wait For Log Entry              PC moved  pauseEmulation=False

Wait for Machine to Reset
    Wait For Log Entry              Machine resetting  pauseEmulation=False

Reset
    [Arguments]                     ${machine_reset}

    IF  ${machine_reset}
        Append To List                  ${FLOW}  machine reset
        Execute Command                 machine Reset
    ELSE
        Append To List                  ${FLOW}  cpu reset
        Execute Command                 cpu Reset
    END

*** Test Cases ***
CPU Should Start
    TRY
        Start Test

        CPU Should Not Be Paused
        CPU Should Not Be Halted
        Time Should Flow
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Pause
    TRY
        Start Test

        Pause CPU

        CPU Should Be Paused
        CPU Should Not Be Halted
        Time Should Not Flow

        Resume CPU

        CPU Should Not Be Paused
        CPU Should Not Be Halted
        Time Should Flow
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Halt
    TRY
        Start Test

        Halt CPU

        CPU Should Not Be Paused
        CPU Should Be Halted
        Time Should Flow

        Resume CPU

        CPU Should Not Be Paused
        CPU Should Be Halted
        Time Should Flow
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Pause and Halt
    TRY
        FOR  ${pause_first}  IN  True  False
            FOR  ${resume_first}  IN  True  False
                Start Test

                IF  ${pause_first}
                    Pause CPU
                    Halt CPU
                ELSE
                    Halt CPU
                    Pause CPU
                END

                CPU Should Be Paused
                CPU Should Be Halted
                Time Should Not Flow

                IF  ${resume_first}
                    Resume CPU

                    CPU Should Not Be Paused
                    CPU Should Be Halted
                    Time Should Flow

                    Unhalt CPU
                ELSE
                    Unhalt CPU

                    CPU Should Be Paused
                    CPU Should Not Be Halted
                    Time Should Not Flow

                    Resume CPU
                END

                CPU Should Not Be Paused
                CPU Should Not Be Halted
                Time Should Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Reset
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test

            Reset                           ${machine_reset}

            CPU Should Not Be Halted

            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
                Wait for PC to Move
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Halt and Reset on Cortex-M
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test

            Halt CPU
            Reset                           ${machine_reset}

            CPU Should Not Be Halted  # For Cortex-M we implement CPUWAIT signal which should unhalt cpu on reset if it's unset. It is unset by default

            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
                Wait for PC to Move
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Halt and Reset on Cortex-A
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test                      is_cortex_m=${False}

            Halt CPU
            Reset                           ${machine_reset}

            CPU Should Be Halted  # For Non Cortex-M halted state shouldn't change on the reset

            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Pause and Reset
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test

            Pause CPU
            Reset                           ${machine_reset}

            CPU Should Not Be Halted
            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
                Wait for PC to Move
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Halt Pause and Reset on Cortex-M
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test

            Pause CPU
            Halt CPU
            Reset                           ${machine_reset}

            CPU Should Not Be Halted
            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
                Wait for PC to Move
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END

CPU Should Halt Pause and Reset on Cortex-A
    TRY
        FOR  ${machine_reset}  IN  True  False
            Start Test                      is_cortex_m=${False}

            Pause CPU
            Halt CPU
            Reset                           ${machine_reset}

            CPU Should Be Halted
            IF  ${machine_reset}
                CPU Should Not Be Paused
                Time Should Flow
                Wait for Machine to Reset
            ELSE
                CPU Should Be Paused
                Time Should Not Flow
            END
        END
    EXCEPT  AS  ${error}
        Fail with Flow Log              ${error}
    END
