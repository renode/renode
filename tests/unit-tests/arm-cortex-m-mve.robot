*** Settings ***
Library                             ${CURDIR}/mve_helpers.py
Library                             Collections
Library                             String

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

    Create Log Tester               1  # Low timeout, since we're testing single instructions at a time.
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

Complex Vector-Vector ${instruction:(vcadd.i|vhcadd.s)}${element_size} ${rotation} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x10017fff300140015001600170018000
    Set Register Q0 To ${op1}
    Set Register Q1 To ${op2}

    Load Program And Execute        ${instruction}${element_size} q2, q0, q1, #${rotation}

    # Calls a helper function defined in mve-helpers.py: `compute_vector_vcadd_result`.
    ${instruction_name}=            Split String  ${instruction}  .
    ${expected_value}=              Run Keyword  Compute Vector ${instruction_name}[0] Result
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

Saturated Vector-${with:(Vector|Scalar)} ${instruction:(vqadd)}.${sign:(s|u)}${element_size} Should Produce Correct Result
    [Arguments]                     ${operand1}
    ...                             ${operand2}
    ...                             ${result}
    ...                             ${got_saturated}

    Reset Emulation
    Create Machine

    # Make sure that FPSCR.QC (saturation bit) is cleared
    Execute Command                 cpu SetRegister "FPSCR" 0x40000

    ${is_signed}=                   Evaluate  $sign.lower() == "s"
    ${with_scalar}=                 Evaluate  $with.lower() == "scalar"

    Set Register Q0 To ${operand1}
    IF  ${with_scalar}
        ${instruction_full}=            Set Variable  ${instruction}.${sign}${element_size} q2, q0, r0
        ${instruction_data}=            Set Variable  q0=${operand1} r0=${operand2} result=${result}  # Only used for printing out error messages
        Execute Command                 cpu SetRegister "r0" ${operand2}
    ELSE
        ${instruction_full}=            Set Variable  ${instruction}.${sign}${element_size} q2, q0, q1
        ${instruction_data}=            Set Variable  q0=${operand1} q1=${operand2} result=${result}  # Only used for printing out error messages
        Set Register Q1 To ${operand2}
    END

    Load Program And Execute        ${instruction_full}

    Register Q2 Should Contain ${result}  message=${instruction_full} with ${instruction_data}  element_size=${element_size}

    # Check if FPSCR.QC (saturation bit) is set properly'
    IF  ${got_saturated}
        Register Should Be Equal        FPSCR  0x8040000  message=${instruction_full} did not set saturation bit with ${instruction_data}
    ELSE
        Register Should Be Equal        FPSCR  0x40000  message=${instruction_full} set saturation bit, even if it should not with ${instruction_data}
    END

Bitwise Vector-Vector ${instruction:(vand|vbic|vorr|vorn|veor)} Should Produce Correct Result
    Reset Emulation
    Create Machine

    ${op1}=                         Set Variable  0x80003000b00070007000b00030007fff
    ${op2}=                         Set Variable  0x10017fff300140015001600170018000
    Set Register Q0 To ${op1}
    Set Register Q1 To ${op2}

    Load Program And Execute        ${instruction} q2, q0, q1
    # Calls a helper function defined in mve-helpers.py: `compute_vector_$insn_result`.
    # They're the partial functions at the very bottom (there's no def, just an assignment).
    ${expected_value}=              Run Keyword  Compute Vector ${instruction} Result
    ...                             ${op1}
    ...                             ${op2}
    Register Q2 Should Contain ${expected_value}  message=${instruction}  element_size=128

Test VPT
    ##################################################################################
    # General idea of this test is to run VPT block with VDUP instruction.
    # VDUP instruction should fill activated lanes with a single hexadecimal symbol.
    #
    # Example:
    #  For VPTET.I16 EQ operand1=0x1111 .... 2211 and operand2=0x1111 (as scalar)
    #  We'll execute:
    #  VPTET.I16 EQ, Q0, R10
    #  VDUPT.8  Q0, R0  then Q0=0xaaaa .... 2211
    #  VDUPE.8  Q0, R0  then Q0=0xaaaa .... bbbb
    #  VDUPT.8  Q0, R0  then Q0=0xcccc .... bbbb
    #  VDUP .8  Q0, R0  then Q0=0xdddd .... dddd
    #

    [Arguments]                     ${data_type}
    ...                             ${element_size}
    ...                             ${comparison}
    ...                             ${predicates}
    ...                             ${with_scalar}
    ...                             ${operand1}
    ...                             ${operand2}
    ${is_signed}=                   Evaluate  $data_type.lower() == "s"

    ${instruction}=                 Evaluate  "VPT" + ''.join($predicates) + ".${data_type}${element_size} ${comparison}, Q0"
    Set Register Q0 To ${operand1}

    # We're adding T as first predicate as VPT will always start with one
    # And we're adding empty predicate as last to test instruction without predication
    ${predicates}=                  Create List  T  @{predicates}  ${EMPTY}

    # If we're using scalar we'll be using R10 register for check operation
    # Otherwise we're using Q1
    IF  ${with_scalar}
        ${instruction}=                 Set Variable  ${instruction}, R10
        Execute Command                 cpu SetRegister "R10" ${operand2}
    ELSE
        ${instruction}=                 Set Variable  ${instruction}, Q1
        Set Register Q1 To ${operand2}
    END

    ${assembly}=                    Set Variable  ${instruction}
    ${values}=                      Create List  0xaa  0xbb  0xcc  0xdd  0xee
    FOR  ${index}  ${predicate}  IN ENUMERATE  @{predicates}
        Execute Command                 cpu SetRegister "R${index}" ${values}[${index}]
        ${assembly}=                    Catenate  SEPARATOR=\n  ${assembly}  VDUP${predicate}.8 Q0, R${index}
    END
    Execute Command                 cpu AssembleBlock ${START_ADDRESS} """${assembly}"""
    Execute Command                 cpu PC ${START_ADDRESS}

    # Mask is a python boolean array signifying which lanes are activate and which are not
    ${mask}=                        Compute VPR Mask
    ...                             ${element_size}
    ...                             ${operand1}
    ...                             ${operand2}
    ...                             ${comparison}
    ...                             ${is_signed}
    ...                             ${with_scalar}
    Execute Command                 cpu Step  # Execute VPT instruction

    # It's here for error message
    ${step_messages}=               Create List
    Append To List                  ${step_messages}  ${SPACE}compare=${operand2}
    Append To List                  ${step_messages}  ${SPACE}initial=${operand1}

    # Steps through each VDUP instruction checking if register got updated correctly
    FOR  ${index}  ${predicate}  IN ENUMERATE  @{predicates}
        ${expected_value}=              Compute VDUP Result
        ...                             element_size_str=8
        ...                             operand_32_bit=${values}[${index}]
        ${expected_value}=              Apply VPR Mask
        ...                             original=${operand1}
        ...                             update=${expected_value}
        ...                             mask=${mask}
        ...                             action=${predicate}
        Execute Command                 cpu Step

        ${operand1}=                    Read Register Q0
        Append To List                  ${step_messages}  ${SPACE}${SPACE}${SPACE}step${index}=${operand1}
        TRY
            Register Q0 Should Contain ${expected_value}  element_size=${128}
        EXCEPT
            Append To List                  ${step_messages}  expected=${expected_value}
            ${message}=                     Catenate  SEPARATOR=\n  @{step_messages}
            Fail                            ${instruction} failed on step ${index}\n${message}
        END
    END

*** Test Cases ***
Vector-Vector Instructions Should Produce Correct Results
    [Template]                      Vector-Vector ${instruction}.${sign}${element_size} Should Produce Correct Result

    FOR  ${instruction}  IN  vhadd  vhsub  vmax  vmin
        FOR  ${sign}  IN  s  u
            FOR  ${element_size}  IN  8  16  32
                ${instruction}                  ${sign}  ${element_size}
            END
        END
    END

Vector-Vector Complex Number Instructions Should Produce Correct Results
    [Template]                      Complex Vector-Vector ${instruction}${element_size} ${rotation} Should Produce Correct Result

    FOR  ${instruction}  IN  vhcadd.s  vcadd.i
        FOR  ${rotation}  IN  90  270
            FOR  ${element_size}  IN  8  16  32
                ${instruction}                  ${element_size}  ${rotation}
            END
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

VQADD Saturation Instruction Should Produce Correct Results
    # Generated with mve-test-generators.py
    Saturated Vector-Scalar vqadd.s8 Should Produce Correct Result
    ...                             operand1=0xd2f6a3e0eddd8da6c5c4aa99b6e5bfb9  operand2=0x79  result=0x4b6f1c596656061f3e3d23122f5e3832  got_saturated=False

    Saturated Vector-Scalar vqadd.s8 Should Produce Correct Result
    ...                             operand1=0x9da58297a799cdb79fb687858988b8ce  operand2=0xa6  result=0x80808080808080808080808080808080  got_saturated=True

    Saturated Vector-Scalar vqadd.s8 Should Produce Correct Result
    ...                             operand1=0x72777a716c6f777d7d74796c7475727a  operand2=0x14  result=0x7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f  got_saturated=True

    Saturated Vector-Vector vqadd.s8 Should Produce Correct Result
    ...                             operand1=0x4fefc81218408bfb38399f11eea4f86e  operand2=0xf4a4dab834e329a23090524af3de7e83  result=0x4393a2ca4c23b49d68c9f15be18276f1  got_saturated=False

    Saturated Vector-Vector vqadd.s8 Should Produce Correct Result
    ...                             operand1=0x979989899185bfc8c48387869281ba8f  operand2=0x8ed6cef5e7eca0a8afc0f6f8d9fab0e8  result=0x80808080808080808080808080808080  got_saturated=True

    Saturated Vector-Vector vqadd.s8 Should Produce Correct Result
    ...                             operand1=0x5573445e6d747e5975765b2f5664736b  operand2=0x5f0e4643182b02366f0a30572e431e56  result=0x7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f  got_saturated=True

    Saturated Vector-Scalar vqadd.s16 Should Produce Correct Result
    ...                             operand1=0x3e7a5898c055576ee9cd31c69c57fc6d  operand2=0xf874  result=0x36ee510cb8c94fe2e2412a3a94cbf4e1  got_saturated=False

    Saturated Vector-Scalar vqadd.s16 Should Produce Correct Result
    ...                             operand1=0x97a281678c54881180c28fffa4b68c1f  operand2=0xd895  result=0x80008000800080008000800080008000  got_saturated=True

    Saturated Vector-Scalar vqadd.s16 Should Produce Correct Result
    ...                             operand1=0x6d1d64845f437d756aa05ae37c615aba  operand2=0x29b4  result=0x7fff7fff7fff7fff7fff7fff7fff7fff  got_saturated=True

    Saturated Vector-Vector vqadd.s16 Should Produce Correct Result
    ...                             operand1=0xe942a99818b08cef332fe21f12371878  operand2=0x240866494bcb7693e3fee8d6d5b49bdf  result=0x0d4a0fe1647b0382172dcaf5e7ebb457  got_saturated=False

    Saturated Vector-Vector vqadd.s16 Should Produce Correct Result
    ...                             operand1=0x98079ec6971b869bca8486f2828eb999  operand2=0xe24fbcf4dce7b9c0906cb5f6e6a5960b  result=0x80008000800080008000800080008000  got_saturated=True

    Saturated Vector-Vector vqadd.s16 Should Produce Correct Result
    ...                             operand1=0x6afc48cb5e3d6560528a7931787e5c36  operand2=0x1e605f673f541dd632990e2f4edc3041  result=0x7fff7fff7fff7fff7fff7fff7fff7fff  got_saturated=True

    Saturated Vector-Scalar vqadd.s32 Should Produce Correct Result
    ...                             operand1=0xd021ce3e36bf8e201408f46a9a849b9f  operand2=0x421fda66  result=0x1241a8a478df68865628ced0dca47605  got_saturated=False

    Saturated Vector-Scalar vqadd.s32 Should Produce Correct Result
    ...                             operand1=0xb0239840a99669e0a46123fdd1274b87  operand2=0x93a23ea8  result=0x80000000800000008000000080000000  got_saturated=True

    Saturated Vector-Scalar vqadd.s32 Should Produce Correct Result
    ...                             operand1=0x520981576655911167c76ad973bf68a0  operand2=0x2fefda07  result=0x7fffffff7fffffff7fffffff7fffffff  got_saturated=True

    Saturated Vector-Vector vqadd.s32 Should Produce Correct Result
    ...                             operand1=0x0137ac8c083f2f9fe9e03ace51edd759  operand2=0x3290f0d770d93add6f4c5d0797744ed0  result=0x33c89d6379186a7c592c97d5e9622629  got_saturated=False

    Saturated Vector-Vector vqadd.s32 Should Produce Correct Result
    ...                             operand1=0xa25b45829780cc75958ea05fa93be69e  operand2=0xb0748766a9b866e39c2abc5fb4a9638c  result=0x80000000800000008000000080000000  got_saturated=True

    Saturated Vector-Vector vqadd.s32 Should Produce Correct Result
    ...                             operand1=0x6e14763e7391fa037497a5d060dfdcc1  operand2=0x3b1cb38b37b1e2586f9cdf96267d54cb  result=0x7fffffff7fffffff7fffffff7fffffff  got_saturated=True

    Saturated Vector-Scalar vqadd.u8 Should Produce Correct Result
    ...                             operand1=0x35984d2d5186096c549d700151771407  operand2=0x54  result=0x89eca181a5da5dc0a8f1c455a5cb685b  got_saturated=False

    Saturated Vector-Scalar vqadd.u8 Should Produce Correct Result
    ...                             operand1=0xaa80787165aeb3ffb19b77f5c676dfe8  operand2=0xb1  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

    Saturated Vector-Vector vqadd.u8 Should Produce Correct Result
    ...                             operand1=0xa2c22872029b8f69041a0466385ca816  operand2=0x24186f26c81f38687ad7f73b860f5776  result=0xc6da9798cabac7d17ef1fba1be6bff8c  got_saturated=False

    Saturated Vector-Vector vqadd.u8 Should Produce Correct Result
    ...                             operand1=0x65fafde5faf2a795a7c6e5aae5eeadc6  operand2=0xee538bf40720bcd3c6455185d6135bec  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

    Saturated Vector-Scalar vqadd.u16 Should Produce Correct Result
    ...                             operand1=0x14ff179b1681183b187c0ae4121613fc  operand2=0xe722  result=0xfc21febdfda3ff5dff9ef206f938fb1e  got_saturated=False

    Saturated Vector-Scalar vqadd.u16 Should Produce Correct Result
    ...                             operand1=0x9a6e5a6a504ff13ca940cbf5ca7e5149  operand2=0xdcdc  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

    Saturated Vector-Vector vqadd.u16 Should Produce Correct Result
    ...                             operand1=0x27d265e6150007f20c78047703ea2bed  operand2=0xbd5c27fcb64e96b5be44eb91f3bd5e80  result=0xe52e8de2cb4e9ea7cabcf008f7a78a6d  got_saturated=False

    Saturated Vector-Vector vqadd.u16 Should Produce Correct Result
    ...                             operand1=0xde615e7eff3df0e8e075773dcbb7dc27  operand2=0x3407caec085d12c9f888f7c5af462c4c  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

    Saturated Vector-Scalar vqadd.u32 Should Produce Correct Result
    ...                             operand1=0x3b52d1d0742394b4432e939c1b074a76  operand2=0x4fcfaaaa  result=0x8b227c7ac3f33f5e92fe3e466ad6f520  got_saturated=False

    Saturated Vector-Scalar vqadd.u32 Should Produce Correct Result
    ...                             operand1=0xebe6577dd83fb4a1f805d6cee4ffec41  operand2=0x2c69e6fb  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

    Saturated Vector-Vector vqadd.u32 Should Produce Correct Result
    ...                             operand1=0x2dfd98ad15498d83714f679d3829bc69  operand2=0x76eb1ffe375eaff102e12f91bff04351  result=0xa4e8b8ab4ca83d747430972ef819ffba  got_saturated=False

    Saturated Vector-Vector vqadd.u32 Should Produce Correct Result
    ...                             operand1=0x6c7862fdc613c30ebdbc8e7557fabbb8  operand2=0xae1cff328c27e4f68a73ba65ba17931d  result=0xffffffffffffffffffffffffffffffff  got_saturated=True

Bitwise Vector-Vector Instructions Should Produce Correct Results
    [Template]                      Bitwise Vector-Vector ${instruction:(vand|vbic|vorr|vorn|veor)} Should Produce Correct Result

    FOR  ${instruction}  IN  vand  vbic  vorr  vorn  veor
        ${instruction}
    END

VPT Should Mask Correct Lanes
    # Checks all the possible predications for VPT block
    Create Machine

    # In this tests operands will be using equality for comparison
    # Operands are picked so that depending on instruction size different set of lanes should activate
    ${operand1}=                    Set Variable  0x1111111122223333445566770f0f0f0f
    ${operand2}=                    Set Variable  0x11111111ffff3333ffffff77f0f0f0f0

    # We're testing all possible predicate sequences to make sure all length of predicates are used properly
    ${predicates_list}=             Evaluate  itertools.chain.from_iterable([itertools.product(['T', 'E'], repeat=r) for r in range(4)])  itertools  #Produces all possible combinations for predicates ie. T, E, TT, TE, TTT...
    FOR  ${predicates}  IN  @{predicates_list}
        FOR  ${element_size}  IN  8  16  32
            Test VPT
            ...                             data_type=I
            ...                             element_size=${element_size}
            ...                             comparison=EQ
            ...                             predicates=${predicates}
            ...                             with_scalar=False
            ...                             operand1=${operand1}
            ...                             operand2=${operand2}
        END
    END

VPT Should Compare Properly
    # Checks all the possible comparisons for VPT instruction
    Create Machine

    ${predicates}=                  Create List  E  # We want to check for comparison and reverse of it just in case
    FOR  ${operand1}  ${operand2}  ${with_scalar}  IN
    # Same test as VPT Should Mask Correct Lanes
    ...  0x1111111122223333445566770f0f0f0f  0x11111111ffff3333ffffff77f0f0f0f0  False
    # Version with scalar
    ...  0x1111111122223333445566770f0f0f0f  0x33  True
    # This one should produce many different results depending on comparison type, the 8s are bit flips to force some values to be interpreted as negative
    ...  0x80008001800000828000800380000084  0x80000002  True
    # Just randomly generated values
    ...  0x760c353ffda6451d58aeb12f78e26f9f  0x70521c7165536bcb311bdec9a8c1bb88  False
        FOR  ${element_size}  IN  8  16  32
            FOR  ${data_type}  IN  I  U  S
                IF  "${data_type}" == "I"
                    ${comparison_list}=             Create List  EQ  NE
                ELSE IF  "${data_type}" == "U"
                    ${comparison_list}=             Create List  HI  CS
                ELSE
                    ${comparison_list}=             Create List  GT  GE  LT  LE
                END
                FOR  ${comparison}  IN  @{comparison_list}
                    Test VPT
                    ...                             data_type=${data_type}
                    ...                             element_size=${element_size}
                    ...                             comparison=${comparison}
                    ...                             predicates=${predicates}
                    ...                             with_scalar=${with_scalar}
                    ...                             operand1=${operand1}
                    ...                             operand2=${operand2}
                END
            END
        END
    END

VPT Should Use Predicated Instruction Version
    # Some instruction in Tlib can use different implementation depending if they are predicated or not
    # This test checks one of these instructions to make sure it uses the predicated version in VPT block
    # That's why we're not stepping this but try to run the assembly as one block
    # We're using VAND as we know it has optimized version
    Create Machine

    ${operand1}=                    Set Variable  0x1111111122223333445566770f0f0f0f
    ${operand2}=                    Set Variable  0x11111111ffff3333ffffff77f0f0f0f0

    # starting_value is basically here to make sure Q2 is 0x0 at the start
    ${starting_value}=              Set Variable  0x00000000000000000000000000000000

    Set Register Q0 To ${operand1}
    Set Register Q1 To ${operand2}
    Set Register Q2 To ${starting_value}

    ${assembly}=                    Catenate  SEPARATOR=;
    ...                             VPT.I16 EQ, Q0, Q1
    ...                             VANDT Q2, Q0, Q1
    Load Program And Execute        ${assembly}

    ${mask}=                        Compute VPR Mask
    ...                             element_size_str=16
    ...                             operand1_str=${operand1}
    ...                             operand2_str=${operand2}
    ...                             comparison_operator=EQ
    ...                             is_signed=False
    ...                             with_scalar=False

    ${expected_value}=              Compute Vector VAND Result
    ...                             ${operand1}
    ...                             ${operand2}
    ${expected_value}=              Apply VPR Mask
    ...                             original=${starting_value}
    ...                             update=${expected_value}
    ...                             mask=${mask}
    ...                             action=T

    Register Q2 Should Contain ${expected_value}  element_size=128
