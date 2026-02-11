*** Settings ***
Library                             ${CURDIR}/mve-helpers.py

*** Variables ***
${START_ADDRESS}                    0x100
${PLATFORM}                         @platforms/cpus/renesas-r7fa8m1a.repl

*** Keywords ***
Load Program And Execute
    [Arguments]                     ${ASSEMBLY}
    ${assembly_size}=               Execute Command  cpu AssembleBlock ${START_ADDRESS} """${ASSEMBLY}"""
    Execute Command                 cpu PC ${START_ADDRESS}

    # Use a hook to detect when the program has finished.
    ${hook}=                        Set Variable  cpu.Log(LogLevel.Info, "'${ASSEMBLY}' finished")
    ${end_of_assembly}=             Evaluate  int($START_ADDRESS, base=16) + int($assembly_size, base=16)
    Execute Command                 cpu RemoveHooksAt ${end_of_assembly}
    Execute Command                 cpu AddHook ${end_of_assembly} """${hook}"""

    # So the CPU doesn't abort.
    ${assembly_size}=               Execute Command  cpu AssembleBlock ${end_of_assembly} "b ."

    Wait For Log Entry              '${ASSEMBLY}' finished

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString """fault: Memory.MappedMemory @ sysbus 0xFFFFFC00 { size: 0x400 }"""

    # Register hook to make invalid instructions fail the test.
    ${hook}=                        Catenate  SEPARATOR=\n
    ...                             fault_pc = machine['sysbus.fault'].ReadDoubleWord(0x3F8)
    ...                             instr = ' '.join(cpu.DisassembleBlock(fault_pc, 8).splitlines()[0].split('\t')[1:])
    ...                             cpu.Log(LogLevel.Error, "Unsupported opcode: {0} @ 0x{1:X}", instr, fault_pc)
    Execute Command                 cpu AddHook 0 """${hook}"""

    Create Log Tester               0.000001  # Low timeout, since we're testing single instructions at a time.
    Register Failing Log String     Unsupported opcode

Set Register Q${index} To ${value_128_bit}
    ${values_32_bit}=               Split Into N Bit Values  32  ${value_128_bit}
    FOR  ${offset}  ${value}  IN ENUMERATE  @{values_32_bit}
        # Q registers are made up of 4 adjacent S registers.
        ${register}=                    Evaluate  int($index)*4 + int($offset)
        Execute Command                 cpu SetRegister "s${register}" ${value}
    END

Register Q${index} Should Contain ${value_128_bit}
    [Arguments]                     ${message}=""
    ${values_32_bit}=               Split Into N Bit Values  32  ${value_128_bit}
    FOR  ${offset}  ${value}  IN ENUMERATE  @{values_32_bit}
        # Q registers are made up of 4 adjacent S registers.
        ${register}=                    Evaluate  int($index)*4 + int($offset)
        Run Keyword And Continue On Failure  Register Should Be Equal  s${register}  ${value}  message=${message}
    END

${instruction:(vhadd|vhsub)}.${sign:(s|u)}${element_size} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x10017fff300140015001600170018000
    Set Register Q0 To ${op1}
    Set Register Q1 To ${op2}

    Load Program And Execute        ${instruction}.${sign}${element_size} q2, q0, q1

    ${is_signed}=                   Evaluate  $sign.lower() == "s"
    # Calls a helper function defined in mve-helpers.py: `compute_$insn_result`.
    # They're the partial functions at the very bottom (there's no def, just an assignment).
    ${expected_value}=              Run Keyword  Compute ${instruction} Result
    ...                             ${element_size}
    ...                             ${op1}
    ...                             ${op2}
    ...                             treat_elements_as_signed=${is_signed}
    Register Q2 Should Contain ${expected_value}  message=${instruction}.${sign}${element_size}

*** Test Cases ***
Vector Instructions Should Produce Correct Results
    [Template]                      ${instruction}.${sign}${element_size} Should Produce Correct Result

    FOR  ${instruction}  IN  vhadd  vhsub
        FOR  ${sign}  IN  s  u
            FOR  ${element_size}  IN  8  16  32
                ${instruction}                  ${sign}  ${element_size}
            END
        END
    END
