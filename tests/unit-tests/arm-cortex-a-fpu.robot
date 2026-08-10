*** Variables ***
${RAM_ADDR}                             0x40000000

# What register the floating point conversions should be stored in
${OUT_FLOAT_REG}                        d0

*** Keywords ***
Create Machine
    Reset Emulation
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescription @platforms/cpus/cortex-a53-gicv3.repl

Assemble Instructions
    [Arguments]                         ${instrs}  ${address}
    Execute Command                     sysbus.cpu AssembleBlock ${address} "${instrs}"

Execute Instructions
    [Arguments]                         ${instrs}  ${step_count}  ${address}=${RAM_ADDR}
    Assemble Instructions               ${instrs}  ${address}
    Execute Command                     sysbus.cpu PC ${RAM_ADDR}
    Execute Command                     sysbus.cpu Step ${step_count}

Int To Float Scaled Store Reg
    [Arguments]                         ${input_int}  ${scale}  ${out_reg}
    Execute Command                     sysbus.cpu SetRegister "x0" ${input_int}
    Execute Instructions                ucvtf ${out_reg},w0,${scale}  step_count=1

Float To Int Scaled From Reg
    [Arguments]                         ${input_reg}  ${scale}
    Execute Instructions                fcvtzu w0,${input_reg},${scale}  step_count=1

Float To Int And Back
    [Arguments]                         ${input_float}  ${expected_float}  ${scale}

    Int To Float Scaled Store Reg       ${input_float}  ${scale}  ${OUT_FLOAT_REG}
    Register Should Be Equal            ${OUT_FLOAT_REG}  ${expected_float}
    Float To Int Scaled From Reg        ${OUT_FLOAT_REG}  ${scale}
    Register Should Be Equal            X0  ${input_float}

*** Test Cases ***
Int To Float And Back
    # Convert some precomputed known values and ensure they translate to float and back to integers as expected

    # All expected values are computed with this scale.
    # Changing `input_scale` requires that you recompute all `expected_float` variables with the new scale
    ${input_scale}=                     Set Variable  0x10  # 16

    ${input_int1}=                      Set Variable  0x2be  # 702
    ${expected_float1}=                 Set Variable  0x3f85f00000000000  # 0.010711669921875

    ${input_int2}=                      Set Variable  0x100  # 256
    ${expected_float2}=                 Set Variable  0x3F70000000000000  # 0.010711669921875

    ${input_int3}=                      Set Variable  0x1  # 1
    ${expected_float3}=                 Set Variable  0x3EF0000000000000  # 0.0000152587890625

    ${input_int4}=                      Set Variable  0xFFFFFFFF  # 4294967295 (U32_MAX)
    ${expected_float4}=                 Set Variable  0x40EFFFFFFFE00000  # 65535.99998474121

    Create Machine

    Float To Int And Back               ${input_int1}  ${expected_float1}  ${input_scale}
    Float To Int And Back               ${input_int2}  ${expected_float2}  ${input_scale}
    Float To Int And Back               ${input_int3}  ${expected_float3}  ${input_scale}
    Float To Int And Back               ${input_int4}  ${expected_float4}  ${input_scale}

Float To Int And Back All Scales
    # Arbitrary value
    ${input_int}=                       Set Variable  0x2be  # 702

    Create Machine

    # Ensure we go through every scale that is available to us (1..=32)
    FOR  ${scale}  IN RANGE  1  33
        Int To Float Scaled Store Reg       ${input_int}  ${scale}  ${OUT_FLOAT_REG}
        Float To Int Scaled From Reg        ${OUT_FLOAT_REG}  ${scale}
        # 'Float To Int Scaled' stores its result in reg w0
        Register Should Be Equal            X0  ${input_int}  message=Expected X0 to contain ${input_int} when scaled with ${scale}
    END
