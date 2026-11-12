*** Settings ***
Library                             u55_commands.py

*** Variables ***
# NPU status after a clean STOP: stop() sets all 16 IRQ-history bits
# (0xFFFF0000), and completion sets IRQ_RAISED (0x2) and CMD_END_REACHED (0x20).
${NPU_STATUS_DONE}                  0xFFFF0022

*** Keywords ***
Create NPU Machine
    [Arguments]                     ${macs}=256
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "ram: Memory.MappedMemory @ sysbus 0 { size: 0x10000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "npu: ARM_Ethos.ARM_EthosU55 @ sysbus 0x40000000 { macsPerCycle: ${macs} }"
    # Size the accumulator buffer based on CONFIG.shram_size, which varies
    # with the MAC count (TRM Table 4-144).
    ${config}=                      Execute Command  sysbus ReadDoubleWord 0x40000028
    ${buffer_end}=                  Evaluate  ((int($config, 0) >> 8) & 0xFF) - 2
    # Valid int8 ADD configuration, one element, no scaling or zero points.
    ${base}=                        Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_PRECISION, ifm_precision(IfmPrecision.S8))
    ...                             cmd0(Cmd0.SET_IFM2_PRECISION, ifm_precision(IfmPrecision.S8))
    ...                             cmd0(Cmd0.SET_OFM_PRECISION, ofm_precision(OfmPrecision.S8, global_scale=True, rounding=Rounding.NATURAL))
    ...                             cmd0(Cmd0.SET_IFM2_IB_START, 10)
    ...                             cmd0(Cmd0.SET_IFM_IB_END, 18)
    ...                             cmd0(Cmd0.SET_AB_START, ${buffer_end})
    ...                             cmd0(Cmd0.SET_ACTIVATION_MIN, -128)
    ...                             cmd0(Cmd0.SET_ACTIVATION_MAX, 127)
    ...                             address(Cmd1.SET_IFM_BASE0, 0x2000)
    ...                             address(Cmd1.SET_IFM2_BASE0, 0x2100)
    ...                             address(Cmd1.SET_OFM_BASE0, 0x3000)
    ...                             scale(Cmd1.SET_OFM_SCALE, 1)
    ...                             scale(Cmd1.SET_OPA_SCALE, 1)
    ...                             scale(Cmd1.SET_OPB_SCALE, 1)
    Set Test Variable               ${BASE_WORDS}  ${base}
    ${int32}=                       Build NPU Commands
    ...                             cmd0(Cmd0.SET_IFM_PRECISION, ifm_precision(IfmPrecision.S32))
    ...                             cmd0(Cmd0.SET_IFM2_PRECISION, ifm_precision(IfmPrecision.S32))
    ...                             cmd0(Cmd0.SET_OFM_PRECISION, ofm_precision(OfmPrecision.S32, global_scale=True, rounding=Rounding.NATURAL))
    ...                             cmd0(Cmd0.SET_OFM_WIDTH_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_IFM_WIDTH0_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_OFM_WIDTH0_M1, 4 - 1)
    ...                             cmd0(Cmd0.SET_IFM2_WIDTH0_M1, 4 - 1)
    ...                             address(Cmd1.SET_IFM_STRIDE_X, 4)
    ...                             address(Cmd1.SET_IFM2_STRIDE_X, 4)
    ...                             address(Cmd1.SET_OFM_STRIDE_X, 4)
    Set Test Variable               ${INT32_WORDS}  ${int32}
    Create Log Tester               0

Write NPU Words
    [Arguments]                     ${address}  ${words}
    ${count}=                       Get Length  ${words}
    FOR  ${index}  IN RANGE  ${count}
        ${word_address}=                Evaluate  $address + 4 * $index
        Execute Command                 sysbus WriteDoubleWord ${word_address} ${words}[${index}]
    END

Submit NPU Words
    [Arguments]                     ${words}  ${with_base}=${True}
    ${stream}=                      Evaluate  ($BASE_WORDS if $with_base else []) + $words
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
