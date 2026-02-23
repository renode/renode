*** Settings ***
Library                             ${CURDIR}/mve-helpers.py
Library                             Collections

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

Read Register Q${index}
    ${s_register_contents}=         Create List
    FOR  ${offset}  IN RANGE  4
        # Q registers are made up of 4 adjacent S registers.
        ${register}=                    Evaluate  int($index)*4 + int($offset)
        ${register_value}=              Execute Command  cpu GetRegister "s${register}"
        Append To List                  ${s_register_contents}  ${{ $register_value.strip() }}
    END
    ${q_register_value}=            Combine N Into 128 Bit Value  32  ${s_register_contents}
    RETURN                          ${q_register_value}

Register Q${index} Should Contain ${value_128_bit}
    [Arguments]                     ${message}=${EMPTY}  ${element_size}=32
    ${q_register_value}=            Read Register Q${index}

    ${actual_elements}=             Split Into N Bit Values  ${element_size}  ${q_register_value}
    ${expected_elements}=           Split Into N Bit Values  ${element_size}  ${value_128_bit}

    ${zipped}=                      Evaluate  list(zip($actual_elements, $expected_elements))
    FOR  ${element_index}  ${pair}  IN ENUMERATE  @{zipped}
        ${actual}=                      Set Variable  ${pair}[0]
        ${expected}=                    Set Variable  ${pair}[1]
        # The list elements are in reversed order, so compute the correct lane number.
        ${lane_number}=                 Evaluate  (128 // int($element_size)) - 1 - $element_index
        Run Keyword And Continue On Failure
        ...                             Should Be Equal
        ...                             ${expected}
        ...                             ${actual}
        ...                             ${message} lane number ${lane_number}
    END

Vector-Vector ${instruction:(vhadd|vhsub)}.${sign:(s|u)}${element_size} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x10017fff300140015001600170018000
    Set Register Q0 To ${op1}
    Set Register Q1 To ${op2}

    Load Program And Execute        ${instruction}.${sign}${element_size} q2, q0, q1

    ${is_signed}=                   Evaluate  $sign.lower() == "s"
    # Calls a helper function defined in mve-helpers.py: `compute_vector_$insn_result`.
    # They're the partial functions at the very bottom (there's no def, just an assignment).
    ${expected_value}=              Run Keyword  Compute Vector ${instruction} Result
    ...                             ${element_size}
    ...                             ${op1}
    ...                             ${op2}
    ...                             treat_elements_as_signed=${is_signed}
    Register Q2 Should Contain ${expected_value}  message=${instruction}.${sign}${element_size}  element_size=${element_size}

VCADD.I${element_size} ${rotation} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x10017fff300140015001600170018000
    Set Register Q0 To ${op1}
    Set Register Q1 To ${op2}

    Load Program And Execute        vcadd.i${element_size} q2, q0, q1, #${rotation}

    # Calls a helper function defined in mve-helpers.py: `compute_vector_vcadd_result`.
    ${expected_value}=              Compute Vector VCADD Result
    ...                             ${element_size}
    ...                             ${op1}
    ...                             ${op2}
    ...                             ${rotation}
    Register Q2 Should Contain ${expected_value}  message=vcadd.i${element_size}  element_size=${element_size}

Vector-Scalar ${instruction:(vhadd|vhsub)}.${sign:(s|u)}${element_size} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x7E
    Set Register Q0 To ${op1}
    Execute Command                 cpu SetRegister "R0" ${op2}

    Load Program And Execute        ${instruction}.${sign}${element_size} q2, q0, r0

    ${is_signed}=                   Evaluate  $sign.lower() == "s"
    # Calls a helper function defined in mve-helpers.py: `compute_scalar_$insn_result`.
    # They're the partial functions at the very bottom (there's no def, just an assignment).
    ${expected_value}=              Run Keyword  Compute Scalar ${instruction} Result
    ...                             ${element_size}
    ...                             ${op1}
    ...                             ${op2}
    ...                             treat_elements_as_signed=${is_signed}
    Register Q2 Should Contain ${expected_value}  message=${instruction}.${sign}${element_size}  element_size=${element_size}

*** Test Cases ***
Vector-Vector Instructions Should Produce Correct Results
    [Template]                      Vector-Vector ${instruction}.${sign}${element_size} Should Produce Correct Result

    FOR  ${instruction}  IN  vhadd  vhsub
        FOR  ${sign}  IN  s  u
            FOR  ${element_size}  IN  8  16  32
                ${instruction}                  ${sign}  ${element_size}
            END
        END
    END

VCADD Should Produce Correct Results
    [Template]                      VCADD.I${element_size} ${rotation} Should Produce Correct Result

    FOR  ${rotation}  IN  90  270
        FOR  ${element_size}  IN  8  16  32
            ${element_size}                 ${rotation}
        END
    END

Vector-Scalar Instructions Should Produce Correct Results
    [Template]                      Vector-Scalar ${instruction}.${sign}${element_size} Should Produce Correct Result

    FOR  ${instruction}  IN  vhadd  vhsub
        FOR  ${sign}  IN  s  u
            FOR  ${element_size}  IN  8  16  32
                ${instruction}                  ${sign}  ${element_size}
            END
        END
    END
