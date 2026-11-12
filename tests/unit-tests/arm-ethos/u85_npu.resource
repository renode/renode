*** Settings ***
Library                             u85_commands.py

*** Variables ***
# NPU status after a clean STOP: stop() sets all 16 IRQ-history bits
# (0xFFFF0000), and completion sets IRQ_RAISED (0x2) and CMD_END_REACHED (0x20).
${U85_NPU_STATUS_DONE}              0xFFFF0022
${U85_NPU_STATUS_PARSE_ERROR}       0x12

*** Keywords ***
Create NPU Machine
    [Arguments]                     ${macs}=256
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "ram: Memory.MappedMemory @ sysbus 0 { size: 0x10000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "npu: ARM_Ethos.ARM_EthosU85 @ sysbus 0x40000000 { macsPerCycle: ${macs} }"
    # A valid int8 setup: identity input/output scales, no output clip, one
    # 16x16 tile and unit horizontal strides.
    ${base}=                        Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_PRECISION, ifm_precision(IfmPrecision.S8))
    ...                             cmd0(Cmd0.SET_IFM2_PRECISION, ifm_precision(IfmPrecision.S8))
    ...                             cmd0(Cmd0.SET_OFM_PRECISION, ofm_precision(OfmPrecision.S8, global_scale=True))
    ...                             cmd0(Cmd0.SET_ACTIVATION, activation(clip=ClipRange.NONE))
    ...                             cmd0(Cmd0.SET_ACTIVATION_MIN, -128)
    ...                             cmd0(Cmd0.SET_ACTIVATION_MAX, 127)
    ...                             cmd0(Cmd0.SET_IFM_BROADCAST, broadcast())
    ...                             cmd0(Cmd0.SET_IFM2_BROADCAST, broadcast())
    ...                             cmd0(Cmd0.SET_IFM_WIDTH0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_IFM_HEIGHT1_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_IFM2_WIDTH0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_IFM2_HEIGHT0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_IFM2_HEIGHT1_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT0_M1, 16 - 1)
    ...                             cmd0(Cmd0.SET_OFM_HEIGHT1_M1, 16 - 1)
    ...                             address(Cmd1.SET_IFM_BASE0, 0x2000)
    ...                             address(Cmd1.SET_IFM2_BASE0, 0x2100)
    ...                             address(Cmd1.SET_OFM_BASE0, 0x3000)
    ...                             address(Cmd1.SET_IFM_STRIDE_X, 1)
    ...                             address(Cmd1.SET_IFM2_STRIDE_X, 1)
    ...                             address(Cmd1.SET_OFM_STRIDE_X, 1)
    ...                             scale(Cmd1.SET_IFM_SCALE, 1)
    ...                             scale(Cmd1.SET_IFM2_SCALE, 1)
    ...                             scale(Cmd1.SET_OFM_SCALE, 1)
    Set Test Variable               ${U85_BASE_WORDS}  ${base}
    Create Log Tester               0

Write NPU Values
    [Arguments]                     ${address}  ${values}  ${element_bytes}=1
    ${words}=                       Pack NPU Words  ${values}  element_bytes=${element_bytes}
    Write NPU Words                 ${address}  ${words}

Write NPU Words
    [Arguments]                     ${address}  ${words}
    ${count}=                       Get Length  ${words}
    FOR  ${index}  IN RANGE  ${count}
        ${word_address}=                Evaluate  $address + 4 * $index
        Execute Command                 sysbus WriteDoubleWord ${word_address} ${words}[${index}]
    END

Submit NPU Words
    [Arguments]                     ${words}  ${with_base}=${True}
    ${stream}=                      Evaluate  ($U85_BASE_WORDS if $with_base else []) + $words
    Write NPU Words                 ${0x1000}  ${stream}
    Execute Command                 sysbus WriteDoubleWord 0x40000010 0x1000
    ${size}=                        Evaluate  4 * len($stream)
    Execute Command                 sysbus WriteDoubleWord 0x40000020 ${size}
    Execute Command                 sysbus WriteDoubleWord 0x40000008 1

NPU Status Should Be
    [Arguments]                     ${expected}
    ${status}=                      Execute Command  sysbus ReadDoubleWord 0x40000004
    Should Be Equal As Integers     ${status}  ${expected}

NPU Output Should Be
    [Arguments]                     ${expected}
    ${length}=                      Get Length  ${expected}
    ${actual}=                      Execute Python  [int(value) for value in self.Machine.SystemBus.ReadBytes(0x3000, ${length})]
    Should Be Equal                 ${actual}  ${expected}

Run Command Stream And Check Parse Error
    [Arguments]                     ${words}  ${reason}
    Submit NPU Words                ${words}
    NPU Status Should Be            ${U85_NPU_STATUS_PARSE_ERROR}
    Wait For Log Entry              ${reason}
