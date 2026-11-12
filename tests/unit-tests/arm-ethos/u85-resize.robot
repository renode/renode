*** Settings ***
Test Setup                          Create NPU Machine
Resource                            u85_npu.resource

*** Keywords ***
Resize Command Stream
    [Arguments]                     ${mode}  ${shift}  @{overrides}
    # Create NPU Machine supplies the int8 precision, activation clip, base
    # pointers and X strides. Resize a 3x1 IFM to a 2x1 OFM. The X step is
    # 3/2, so the second output column samples halfway between inputs 1 and 2.
    ${words}=                       Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_WIDTH0_M1, 3 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT0_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT1_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH0_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT0_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT1_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_KERNEL_WIDTH_M1, 3 - 1)
    ...                             cmd0(Cmd0.SET_KERNEL_HEIGHT_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_X_SCALE_N_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_Y_SCALE_N_M1, 1 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_X_OFFSET, 0)
    ...                             cmd0(Cmd0.SET_RESIZE_Y_OFFSET, 0)
    ...                             resize_step(Cmd1.SET_RESIZE_X_STEP, one_step_int=1, one_step_mod=1)
    ...                             resize_step(Cmd1.SET_RESIZE_Y_STEP, one_step_int=1)
    ...                             scale(Cmd1.SET_OFM_SCALE, 1, shift=${shift}, rounding=Rounding.TRUNCATE_TO_LOWER)
    ...                             @{overrides}
    ...                             cmd0(Cmd0.OP_RESIZE, ${mode})
    ...                             stop()
    RETURN                          ${words}

*** Test Cases ***
Bilinear Resize Interpolates
    # IFM bytes 10, 20, 40. Bilinear weights the second output column equally.
    Write NPU Values                ${0x2000}  ${{[10, 20, 40]}}
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_DONE}
    ${expected}=                    Evaluate  [10, 30]
    NPU Output Should Be            ${expected}

Replicate Resize Uses The First Sample
    # Replicate takes the integer position, so the second column is 20.
    Write NPU Values                ${0x2000}  ${{[10, 20, 40]}}
    ${words}=                       Resize Command Stream  Resize.REPLICATE  16
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_DONE}
    ${expected}=                    Evaluate  [10, 20]
    NPU Output Should Be            ${expected}

Nearest Resize Picks The Closest Sample
    # The second column is exactly halfway, so nearest picks the upper sample.
    Write NPU Values                ${0x2000}  ${{[10, 20, 40]}}
    ${words}=                       Resize Command Stream  Resize.NEAREST  16
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_DONE}
    ${expected}=                    Evaluate  [10, 40]
    NPU Output Should Be            ${expected}

Bilinear Resize Handles Both Axes And Clamped Edges
    # Resize [[-8, 8], [24, 40]] to 4x4. Both axes sample -1/4, 1/4,
    # 3/4, 5/4, exercising negative offsets, fractional carries and both edges.
    # Shift 20 divides by 4*4 after the U85's implicit left shift of 16 (TRM 3.10.11).
    Write NPU Values                ${0x2000}  ${{[[-8, 8], [24, 40]]}}
    ${overrides}=                   Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_WIDTH0_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT0_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT1_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH0_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT0_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT1_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_KERNEL_WIDTH_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_KERNEL_HEIGHT_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_X_SCALE_N_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_Y_SCALE_N_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_RESIZE_X_OFFSET, -1 & 0xFFF)
    ...                             cmd0(Cmd0.SET_RESIZE_Y_OFFSET, -1 & 0xFFF)
    ...                             resize_step(Cmd1.SET_RESIZE_X_STEP, one_step_mod=2)
    ...                             resize_step(Cmd1.SET_RESIZE_Y_STEP, one_step_mod=2)
    ...                             address(Cmd1.SET_IFM_STRIDE_Y, 2)
    ...                             address(Cmd1.SET_OFM_STRIDE_Y, 4)
    ${words}=                       Resize Command Stream  Resize.BILINEAR  20  ${overrides}
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_DONE}
    ${expected}=                    Evaluate  [v & 0xFF for v in [-8, -4, 4, 8, 0, 4, 12, 16, 16, 20, 28, 32, 24, 28, 36, 40]]
    NPU Output Should Be            ${expected}

Bilinear Resize Rounds Signed16 Channels
    # Three columns, two int16 channels: [-300, 300], [-301, 301], [-304, 304].
    # The second output column averages to [-302.5, 302.5]. Symmetric rounding
    # rounds both ties away from zero (TRM 3.6.6). Resize ignores the multiplier.
    Write NPU Values                ${0x2000}  ${{[[-300, 300], [-301, 301], [-304, 304]]}}  element_bytes=2
    ${overrides}=                   Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_PRECISION, ifm_precision(IfmPrecision.S16))
    ...                             cmd0(Cmd0.SET_OFM_PRECISION, ofm_precision(OfmPrecision.S16, global_scale=True))
    ...                             cmd0(Cmd0.SET_IFM_DEPTH_M1, 2 - 1)
    ...                             cmd0(Cmd0.SET_OFM_DEPTH_M1, 2 - 1)
    ...                             address(Cmd1.SET_IFM_STRIDE_X, 4)
    ...                             address(Cmd1.SET_OFM_STRIDE_X, 4)
    ...                             scale(Cmd1.SET_OFM_SCALE, 7, shift=17, rounding=Rounding.SYMMETRIC)
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_DONE}
    ${expected}=                    Evaluate  list(struct.pack('<4h', -300, 300, -303, 303))  modules=struct
    NPU Output Should Be            ${expected}

Resize Rejects An Invalid Mode
    ${words}=                       Resize Command Stream  3  16
    Run Command Stream And Check Parse Error  ${words}  Unsupported resize mode: 3

Resize Requires Global Output Scaling
    ${overrides}=                   Build NPU Commands
    ...                             cmd0(Cmd0.SET_OFM_PRECISION, ofm_precision(OfmPrecision.S8, global_scale=False))
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Run Command Stream And Check Parse Error  ${words}  Invalid resize configuration: global output scaling is required

Resize Rejects A Short Output Scale Shift
    ${words}=                       Resize Command Stream  Resize.BILINEAR  15
    Run Command Stream And Check Parse Error  ${words}  Invalid resize configuration: output scale shift must be at least 16

Resize Rejects An X Step Modulo At Least The Scale
    ${overrides}=                   Build NPU Commands
    ...                             resize_step(Cmd1.SET_RESIZE_X_STEP, one_step_int=1, one_step_mod=2)
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Run Command Stream And Check Parse Error  ${words}  Resize X step modulo 2 must be less than scale 2

Resize Rejects An X Offset Outside The Scale Range
    ${overrides}=                   Build NPU Commands
    ...                             cmd0(Cmd0.SET_RESIZE_X_OFFSET, 2)
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Run Command Stream And Check Parse Error  ${words}  Resize X offset 2 is outside the range [-2, 2)

Resize Rejects An Unsupported IFM Precision
    ${overrides}=                   Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_PRECISION, ifm_precision(IfmPrecision.S32))
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Run Command Stream And Check Parse Error  ${words}  Invalid resize configuration: unsupported IFM precision: 0x0009

Resize Rejects A Last Column That Misses The IFM Edge
    ${overrides}=                   Build NPU Commands
    ...                             resize_step(Cmd1.SET_RESIZE_X_STEP, one_step_int=0, one_step_mod=0)
    ${words}=                       Resize Command Stream  Resize.BILINEAR  17  ${overrides}
    Run Command Stream And Check Parse Error  ${words}  Resize X scaling does not map the last OFM column to the last IFM column
