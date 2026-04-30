*** Settings ***
Test Setup                          Create Machine and Start FPU

*** Variables ***
${START_ADDRESS}                    0x0
${PLATFORM}                         platforms/cpus/renesas-r7fa8m1a.repl

*** Keywords ***
Load Program And Execute
    [Arguments]                     ${ASSEMBLY}  ${STEPS}=${0}
    Execute Command                 cpu AssembleBlock ${START_ADDRESS} """${ASSEMBLY}"""
    Execute Command                 cpu PC ${START_ADDRESS}
    IF  ${STEPS} > 0
        Execute Command                 cpu Step ${STEPS}
    END

Create Machine and Start FPU
    [Arguments]                     ${trustZoneEnabled}=${False}

    Execute Command                 mach create

    ${platform_string}=             Catenate  SEPARATOR=\n
    ...                             using "${PLATFORM}"
    ...
    ...                             cpu: {enableTrustZone: ${trustZoneEnabled}}
    Execute Command                 machine LoadPlatformDescriptionFromString """${platform_string}"""

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             ldr r0, =0xE000ED88
    ...                             ldr r1, [r0]
    ...                             orr r1, r1, #0x00F00000
    ...                             str r1, [r0]
    ...                             dsb
    ...                             isb
    Load Program And Execute        ASSEMBLY=${program}  STEPS=6

Get Register Prefix On ${precision:(f16|f32|f64)}
    ${register}=                    Set Variable If  "${precision}" in ["f16", "f32"]
    ...                             s
    ...                             d
    RETURN                          ${register}

Get Registers On ${precision:(f16|f32|f64)}
    IF  "${precision}" in ["f16", "f32"]
        ${registers}=                   Evaluate  [f"s{id}" for id in range(0,32,1)]
    ELSE
        ${registers}=                   Evaluate  [f"d{id}" for id in range(0,16,1)]
    END
    RETURN                          ${registers}

Register Bit Should Be ${is_set:(Unset|Set)}
    [Arguments]                     ${register}  ${bit}
    ${register_value}=              Execute Command  cpu GetRegister "${register}"
    ${bit_value}=                   Evaluate  int("${is_set}" == "Set")
    Should Be True                  ((${register_value} >> ${bit}) & 1) == ${bit_value}

Populate FP Registers On ${precision:(f16|f32|f64)}
    [Arguments]                     ${values}

    ${registers}=                   Get Registers On ${precision}

    FOR  ${register}  ${value}  IN ZIP  ${registers}  ${values}
        Execute Command                 cpu SetRegister "${register}" ${value}
    END

FP Registers Should Be Equal On ${precision:(f16|f32|f64)}
    [Arguments]                     ${expected_values}
    ...                             ${message}=${None}

    ${registers}=                   Get Registers On ${precision}

    FOR  ${register}  ${value}  IN ZIP  ${registers}  ${expected_values}
        Register Should Be Equal        ${register}  ${value}  message=${message}
    END

Read Memory
    [Arguments]                     ${address}
    ...                             ${element_size}

    IF  ${element_size} == 8
        ${value}=                       Execute Command  sysbus ReadByte ${address}
    ELSE IF  ${element_size} == 16
        ${value}=                       Execute Command  sysbus ReadWord ${address}
    ELSE IF  ${element_size} == 32
        ${value}=                       Execute Command  sysbus ReadDoubleWord ${address}
    ELSE
        Fail                            Invalid element_size=${element_size}
    END
    [Return]                        ${value[:-2]}

Write Memory
    [Arguments]                     ${address}
    ...                             ${value}
    ...                             ${element_size}

    IF  ${element_size} == 8
        Execute Command                 sysbus WriteByte ${address} ${value}
    ELSE IF  ${element_size} == 16
        Execute Command                 sysbus WriteWord ${address} ${value}
    ELSE IF  ${element_size} == 32
        Execute Command                 sysbus WriteDoubleWord ${address} ${value}
    ELSE
        Fail                            Invalid element_size=${element_size}
    END

Memory Should Be Equal
    [Arguments]                     ${address}
    ...                             ${expected_value}
    ...                             ${element_size}
    ...                             ${message}=${None}

    ${value}=                       Read Memory  ${address}  ${element_size}

    TRY
        Should Be Equal As Integers     ${value}  ${expected_value}
    EXCEPT
        Fail                            ${message}: Value on address ${{hex(${address})}} assertion failed, actual: ${{hex(${value})}}, expected: ${{hex(${expected_value})}}
    END

Memory Range Should Be Equal
    [Arguments]                     ${address}
    ...                             ${expected_values}
    ...                             ${element_size}
    ...                             ${message}=${None}

    FOR  ${index}  ${expected_value}  IN ENUMERATE  @{expected_values}
        Memory Should Be Equal          ${{${address}+${index}*${element_size}//8}}  ${expected_value}  ${element_size}  ${message} (offset ${index})
    END

Test VRINT* ${precision} Rounding With ${initial}
    [Arguments]
    ...                             ${TIES_AWAY}  ${TIES_EVEN}  ${PLUS_INFINITY}
    ...                             ${MINUS_INFINITY}  ${TOWARDS_ZERO}
    ${register}=                    Get Register Prefix On ${precision}

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vmov.${precision} ${register}0, \#${initial}
    ...                             vrinta.${precision} ${register}1, ${register}0  # Round to nearest, ties away
    ...                             vrintn.${precision} ${register}2, ${register}0  # Round to nearest, ties to even
    ...                             vrintp.${precision} ${register}3, ${register}0  # Round toward plus infinity
    ...                             vrintm.${precision} ${register}4, ${register}0  # Round toward minus infinity
    ...                             vrintz.${precision} ${register}5, ${register}0  # Round toward zero
    Load Program And Execute        ASSEMBLY=${program}  STEPS=6

    Register Should Be Equal        ${register}1  ${TIES_AWAY}
    Register Should Be Equal        ${register}2  ${TIES_EVEN}
    Register Should Be Equal        ${register}3  ${PLUS_INFINITY}
    Register Should Be Equal        ${register}4  ${MINUS_INFINITY}
    Register Should Be Equal        ${register}5  ${TOWARDS_ZERO}

Test VCVT* ${sign} ${precision} Rounding With ${initial}
    [Arguments]
    ...                             ${TIES_AWAY}  ${TIES_EVEN}
    ...                             ${PLUS_INFINITY}  ${MINUS_INFINITY}
    ${register}=                    Get Register Prefix On ${precision}

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vmov.${precision} ${register}0, \#${initial}
    ...                             vcvta.${sign}.${precision} s2, ${register}0  # Round to nearest ties away
    ...                             vcvtn.${sign}.${precision} s3, ${register}0  # Round to nearest with ties to even
    ...                             vcvtp.${sign}.${precision} s4, ${register}0  # Round towards plus infinity
    ...                             vcvtm.${sign}.${precision} s5, ${register}0  # Round towards minus infinity.
    Load Program And Execute        ASSEMBLY=${program}  STEPS=5

    Register Should Be Equal        s2  ${TIES_AWAY}
    Register Should Be Equal        s3  ${TIES_EVEN}
    Register Should Be Equal        s4  ${PLUS_INFINITY}
    Register Should Be Equal        s5  ${MINUS_INFINITY}

Test VSEL ${precision}
    [Arguments]                     ${VALUE_Sn}  ${VALUE_Sm}
    ${register}=                    Get Register Prefix On ${precision}

    Execute Command                 cpu SetRegister "${register}0" ${VALUE_Sn}
    Execute Command                 cpu SetRegister "${register}1" ${VALUE_Sm}
    Execute Command                 cpu SetRegister "cpsr" 0x91000000  # set N,V = 1 & Z = 0

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vselge.${precision} ${register}2, ${register}0, ${register}1  # Sn (Sn if N=V)
    ...                             vselgt.${precision} ${register}3, ${register}0, ${register}1  # Sn (Sn if Z=0 && N=V)
    ...                             vseleq.${precision} ${register}4, ${register}0, ${register}1  # Sm (Sn if Z=1)
    ...                             vselvs.${precision} ${register}5, ${register}0, ${register}1  # Sn (Sn if V=1)
    Load Program And Execute        ASSEMBLY=${program}  STEPS=4

    Register Should Be Equal        ${register}2  ${VALUE_Sn}
    Register Should Be Equal        ${register}3  ${VALUE_Sn}
    Register Should Be Equal        ${register}4  ${VALUE_Sm}
    Register Should Be Equal        ${register}5  ${VALUE_Sn}

Test VSCCLRM ${precision}
    [Arguments]                     ${clear_start}
    ...                             ${clear_end}

    ${prefix}=                      Get Register Prefix On ${precision}
    ${registers_number}=            Set Variable  ${32}
    ${register_values}=             Evaluate  [ i+1 for i in range($registers_number) ]  # 1, 2, 3 ... 31, 32

    Populate FP Registers On f32    ${register_values}
    Load Program And Execute        ASSEMBLY=VSCCLRM {${prefix}${clear_start}-${prefix}${clear_end}, VPR}  STEPS=1

    # Update the range to the way it's stored in Robot
    ${clear_end}=                   Evaluate  ${clear_end}+1
    IF  "${prefix}" == "d"
        ${clear_start}=                 Evaluate  ${clear_start}*2
        ${clear_end}=                   Evaluate  ${clear_end}*2
    END

    FP Registers Should Be Equal On f32  ${{ $register_values[0:${clear_start}] + [0]*(${clear_end}-${clear_start}) + $register_values[${clear_end}:${registers_number}] }}

*** Test Cases ***
Should Round With VRINT*
    [Tags]                          robot:continue-on-failure
    Test VRINT* f32 Rounding With 0.5
    ...                             TIES_AWAY=0x3f800000  TIES_EVEN=0x00000000  PLUS_INFINITY=0x3f800000
    ...                             MINUS_INFINITY=0x00000000  TOWARDS_ZERO=0x00000000

    Test VRINT* f64 Rounding With 0.5
    ...                             TIES_AWAY=0x3ff0000000000000  TIES_EVEN=0x0000000000000000  PLUS_INFINITY=0x3ff0000000000000
    ...                             MINUS_INFINITY=0x0000000000000000  TOWARDS_ZERO=0x0000000000000000

    Test VRINT* f32 Rounding With -0.5
    ...                             TIES_AWAY=0xbf800000  TIES_EVEN=0x80000000  PLUS_INFINITY=0x80000000
    ...                             MINUS_INFINITY=0xbf800000  TOWARDS_ZERO=0x80000000

    Test VRINT* f64 Rounding With -0.5
    ...                             TIES_AWAY=0xbff0000000000000  TIES_EVEN=0x8000000000000000  PLUS_INFINITY=0x8000000000000000
    ...                             MINUS_INFINITY=0xbff0000000000000  TOWARDS_ZERO=0x8000000000000000

    Test VRINT* f32 Rounding With 1.5
    ...                             TIES_AWAY=0x40000000  TIES_EVEN=0x40000000  PLUS_INFINITY=0x40000000
    ...                             MINUS_INFINITY=0x3f800000  TOWARDS_ZERO=0x3f800000

    Test VRINT* f64 Rounding With 1.5
    ...                             TIES_AWAY=0x4000000000000000  TIES_EVEN=0x4000000000000000  PLUS_INFINITY=0x4000000000000000
    ...                             MINUS_INFINITY=0x3ff0000000000000  TOWARDS_ZERO=0x3ff0000000000000

    Test VRINT* f32 Rounding With -1.75
    ...                             TIES_AWAY=0xc0000000  TIES_EVEN=0xc0000000  PLUS_INFINITY=0xbf800000
    ...                             MINUS_INFINITY=0xc0000000  TOWARDS_ZERO=0xbf800000

    Test VRINT* f64 Rounding With -1.75
    ...                             TIES_AWAY=0xc000000000000000  TIES_EVEN=0xc000000000000000  PLUS_INFINITY=0xbff0000000000000
    ...                             MINUS_INFINITY=0xc000000000000000  TOWARDS_ZERO=0xbff0000000000000

Should Handle Special Values With VRINTA
    [Tags]                          robot:continue-on-failure

    FOR  ${value}  ${result}  ${precision}  IN
    ...  0x7f800000  0x7f800000  f32  # Inf
    ...  0xff800000  0xff800000  f32  # -Inf
    ...  0x7fc00000  0x7fc00000  f32  # Nan
    ...  0x7ff0000000000000  0x7ff0000000000000  f64  # Inf
    ...  0xfff0000000000000  0xfff0000000000000  f64  # -Inf
    ...  0x7ff8000000000000  0x7ff8000000000000  f64  # Nan
        ${register}=                    Get Register Prefix On ${precision}

        Execute Command                 cpu SetRegister "${register}0" ${value}

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vrinta.${precision} ${register}1, ${register}0
        Load Program And Execute        ASSEMBLY=${program}  STEPS=1

        Register Should Be Equal        ${register}1  ${result}
    END

Should Round Properly With VRINTR and VRINTX
    [Tags]                          robot:continue-on-failure

    FOR  ${precision}  ${result}  IN
    ...  f32  0x3f800000
    ...  f64  0x3ff0000000000000
        ${register}=                    Get Register Prefix On ${precision}
        ${value}=                       Set Variable  0.25

        Execute Command                 cpu SetRegister "R0" 0x400000  #Bits [23:22] are set to 0b01 - round toward plus infinity mode

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vmsr fpscr, R0  # Load rounding mode to fpscr and create new fp context if needed
        ...                             vmov.${precision} ${register}0, \#${value}
        ...                             vrintm.${precision} ${register}3, ${register}0  # Round toward minus infinity
        ...                             vrintr.${precision} ${register}1, ${register}0
        ...                             vrintx.${precision} ${register}2, ${register}0
        Load Program And Execute        ASSEMBLY=${program}  STEPS=5

        Register Should Be Equal        ${register}1  ${result}
        Register Should Be Equal        ${register}2  ${result}
    END

Should Raise Inexact Exception For VRINTX
    [Tags]                          robot:continue-on-failure

    FOR  ${precision}  IN  f32  f64
        ${register}=                    Get Register Prefix On ${precision}

        Execute Command                 cpu SetRegister "fpscr" 0x0

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vmov.${precision} ${register}0, \#1.0
        ...                             vrintx.${precision} ${register}1, ${register}0  # Shouldn't raise inexact exception
        ...                             vmov.${precision} ${register}0, \#0.5
        ...                             vrintx.${precision} ${register}1, ${register}0  # Should raise inexact exception
        Load Program And Execute        ASSEMBLY=${program}  STEPS=2

        Register Bit Should Be Unset    fpscr  4
        Execute Command                 cpu Step 2
        Register Bit Should Be Set      fpscr  4
    END

Should Round With VCVT*
    [Tags]                          robot:continue-on-failure
    ${neg_1}=                       Set Variable  0xffffffff
    ${neg_2}=                       Set Variable  0xfffffffe
    FOR  ${sign}  IN  s32  u32
        IF  "${sign}" == "u32"
            ${neg_1}=                       Set Variable  0
            ${neg_2}=                       Set Variable  0
        END
        FOR  ${precision}  IN  f32  f64
            Test VCVT* ${sign} ${precision} Rounding With 0.5
            ...                             TIES_AWAY=1  TIES_EVEN=0  PLUS_INFINITY=1
            ...                             MINUS_INFINITY=0

            Test VCVT* ${sign} ${precision} Rounding With -0.5
            ...                             TIES_AWAY=${neg_1}  TIES_EVEN=0  PLUS_INFINITY=0
            ...                             MINUS_INFINITY=${neg_1}

            Test VCVT* ${sign} ${precision} Rounding With 1.5
            ...                             TIES_AWAY=2  TIES_EVEN=2  PLUS_INFINITY=2
            ...                             MINUS_INFINITY=1

            Test VCVT* ${sign} ${precision} Rounding With -1.75
            ...                             TIES_AWAY=${neg_2}  TIES_EVEN=${neg_2}  PLUS_INFINITY=${neg_1}
            ...                             MINUS_INFINITY=${neg_2}
        END
    END

Should Run VMAXNM, VMINNM
    [Tags]                          robot:continue-on-failure

    FOR  ${precision}  ${result_max}  ${result_min}  IN
    ...  f32  0x3e800000  0xbe800000
    ...  f64  0x3fd0000000000000  0xbfd0000000000000
        ${value_1}=                     Set Variable  -0.25
        ${value_2}=                     Set Variable  0.25

        ${register}=                    Get Register Prefix On ${precision}

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vmov.${precision} ${register}0, \#${value_1}
        ...                             vmov.${precision} ${register}1, \#${value_2}
        ...                             vmaxnm.${precision} ${register}2, ${register}0, ${register}1
        ...                             vminnm.${precision} ${register}3, ${register}0, ${register}1
        Load Program And Execute        ASSEMBLY=${program}  STEPS=4

        Register Should Be Equal        ${register}2  ${result_max}
        Register Should Be Equal        ${register}3  ${result_min}
    END

Should Return Number on (Number,NaN) pair for VMAXNM, VMINNM
    [Tags]                          robot:continue-on-failure

    FOR  ${precision}  ${result}  ${quiet_NaN}  IN
    ...  f32  0x3e800000  0x7FC00000
    ...  f64  0x3fd0000000000000  0x7FF8000000000000
        ${register}=                    Get Register Prefix On ${precision}

        Execute Command                 cpu SetRegister "${register}0" ${quiet_NaN}
        Execute Command                 cpu SetRegister "${register}1" ${result}

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vmaxnm.${precision} ${register}2, ${register}0, ${register}1
        ...                             vminnm.${precision} ${register}3, ${register}0, ${register}1
        Load Program And Execute        ASSEMBLY=${program}  STEPS=2

        Register Should Be Equal        ${register}2  ${result}
        Register Should Be Equal        ${register}3  ${result}
    END

Should Run VSEL
    [Tags]                          robot:continue-on-failure

    Test VSEL f16                   VALUE_Sn=0x3e00  VALUE_Sm=0x4100
    Test VSEL f32                   VALUE_Sn=0x3fc00000  VALUE_Sm=0x40200000
    Test VSEL f64                   VALUE_Sn=0x3ff8000000000000  VALUE_Sm=0x4004000000000000

Should Run VINS, VMOVX
    [Tags]                          robot:continue-on-failure
    Execute Command                 cpu SetRegister "s0" 0xF  # Set s0 = 0x0000000F
    Execute Command                 cpu SetRegister "s1" 0xF  # Set s1 = 0x0000000F
    Execute Command                 cpu SetRegister "s2" 0xDF000000  # Set s2 = 0xDF000000

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vins.f16 s0, s1  # s0 = 0x000F000F
    ...                             vmovx.f16 s0, s2  # s0 = 0x0000DF00
    Load Program And Execute        ASSEMBLY=${program}  STEPS=1

    Register Should Be Equal        s0  0x000F000F
    Execute Command                 cpu Step 1
    Register Should Be Equal        s0  0x0000DF00

Should Clean Different Ranges with VSCCLRM
    [Setup]                         Create Machine and Start FPU  trustZoneEnabled=${True}

    Load Program And Execute        ASSEMBLY=VMOV s0, s0  STEPS=1  # Create fp context

    Execute Command                 cpu SetRegister "VPR" 0x10011001  # Set VPR to check if it's also cleared

    Test VSCCLRM f32                clear_start=0  clear_end=31  # Clear all single precision registers
    Test VSCCLRM f64                clear_start=0  clear_end=15  # Clear all double precision registers
    Test VSCCLRM f32                clear_start=9  clear_end=18  # Clear specified range of single precision registers
    Test VSCCLRM f64                clear_start=6  clear_end=9  # Clear specified range of double precision registers

    Register Should Be Equal        VPR  0x0  # VPR should be cleared after all these instructions

Should Run VLSTM
    [Setup]                         Create Machine and Start FPU  trustZoneEnabled=${True}

    ${memory_address}=              Set Variable  ${0x22000000}
    ${result_stride}=               Set Variable  ${256}
    ${registers_number}=            Set Variable  ${32}
    ${register_values}=             Evaluate  [ i+1 for i in range($registers_number)]  # 1, 2, 3 ... 31, 32
    ${fpscr_value}=                 Set Variable  ${0x40000}
    ${vpr_value}=                   Set Variable  ${0x0}

    ${set_ts}=                      Catenate  SEPARATOR=\n
    ...                             ldr r10, =0xE000EF34
    ...                             ldr r11, [r10]
    ...                             orr r11, r11, #0x04000000
    ...                             str r11, [r10]

    ${unset_lspen}=                 Catenate  SEPARATOR=\n
    ...                             ldr r10, =0xE000EF34
    ...                             ldr r11, [r10]
    ...                             bic r11, r11, #0x40000000
    ...                             str r11, [r10]

    Execute Command                 cpu SetRegister "r0" ${memory_address}
    Populate FP Registers On f32    ${register_values}

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vlstm R0  # Run VLSTM without context, it should act as NOP
    ...                               # Create floating point context
    ...                             vmov.f32 s0, s0
    ...                             add r0, #${result_stride}
    ...                             vlstm R0  # Set FPCCR.LSPEN to 1 and destination address to one from R0
    ...                             vmov.f32 s0, s0  # Do lazy fp preservation writing registers s0-s15
    ...                               # Set TS flag
    ...                             ${set_ts}
    ...                             add r0, #${result_stride}
    ...                             vlstm R0  # Set FPCCR.LSPEN to 1 and destination address to one from R0
    ...                             vmov.f32 s0, s0  # Do lazy fp preservation writing registers s0-s32
    ...                               # Disable LSPEN flag
    ...                             ${unset_lspen}
    ...                             add r0, #${result_stride}
    ...                             vlstm R0  # Set FPCCR.LSPEN to 1 and destination address to one from R0
    Load Program And Execute        ASSEMBLY=${program}  STEPS=0

    Execute Command                 cpu Step 2
    Memory Range Should Be Equal    address=${{ $memory_address + $result_stride * 0 }}  expected_values=${{ [0]*(16+2+16) }}  element_size=32  message=VLSTM without FP context  # Nothing should be written

    Populate FP Registers On f32    ${register_values}  # Populate registers again as they are in unknown state
    Execute Command                 cpu Step 3
    Memory Range Should Be Equal    address=${{ $memory_address + $result_stride * 1 }}  expected_values=${{ $register_values[0:16] + [$fpscr_value, $vpr_value] + [0]*16 }}  element_size=32  message=VLSTM without TS set  # Only first 16 registers should be saved

    Populate FP Registers On f32    ${register_values}  # Populate registers again as they are in unknown state
    Execute Command                 cpu Step 7
    FP Registers Should Be Equal On f32  ${{ [0]*32 }}  message=VLSTM with TS set  # Registers should be set to 0
    Memory Range Should Be Equal    address=${{ $memory_address + $result_stride * 2 }}  expected_values=${{ $register_values[0:16] + [$fpscr_value, $vpr_value] + $register_values[16:32] }}  element_size=32  message=VLSTM with TS set  # All 32 registers should be saved

    Populate FP Registers On f32    ${register_values}  # Populate registers again as they are equal 0
    Execute Command                 cpu Step 6
    FP Registers Should Be Equal On f32  ${{ [0]*32 }}  message=VLSTM without LSPEN  # TS is still set so registers should be set to 0
    Memory Range Should Be Equal    address=${{ $memory_address + $result_stride * 3 }}  expected_values=${{ $register_values[0:16] + [$fpscr_value, $vpr_value] + $register_values[16:32] }}  element_size=32  message=VLSTM without LSPEN  # Saving should have happened during execution of VLSTM

Should Run VLLDM
    [Setup]                         Create Machine and Start FPU  trustZoneEnabled=${True}

    ${memory_address}=              Set Variable  ${0x22000000}
    ${result_stride}=               Set Variable  ${256}
    ${registers_number}=            Set Variable  ${32}
    ${register_values}=             Evaluate  [ i+1 for i in range($registers_number)]  # 1, 2, 3 ... 31, 32
    ${vpr_value}=                   Set Variable  ${0x10011001}

    ${set_ts}=                      Catenate  SEPARATOR=\n
    ...                             ldr r10, =0xE000EF34
    ...                             ldr r11, [r10]
    ...                             orr r11, r11, #0x04000000
    ...                             str r11, [r10]

    Execute Command                 cpu SetRegister "r0" ${memory_address}
    Populate FP Registers On f32    ${register_values}

    ${program}=                     Catenate  SEPARATOR=\n
    ...                             vmov.f32 s0, s0  # Create floating point context
    ...                             vlstm R0
    ...                             vscclrm {s0-s31, VPR}  # Do lazy fp preservation and clear registers
    ...                             vlldm R0
    ...                               # Set TS flag
    ...                             ${set_ts}
    ...                             add r0, #${result_stride}
    ...                             vlstm R0
    ...                             vscclrm {s0-s31, VPR}  # Do lazy fp preservation and make sure registers are cleared
    ...                             vlldm R0
    ...                               # Test VLSTM, VLLDM pair without lazy fp preservation
    ...                             add r0, #${result_stride}
    ...                             vlstm R0
    ...                             vlldm R0

    Load Program And Execute        ASSEMBLY=${program}  STEPS=1

    Execute Command                 cpu SetRegister "VPR" ${vpr_value}
    Execute Command                 cpu Step 3
    FP Registers Should Be Equal On f32  ${{ $register_values[0:16] + [0]*16 }}  message=VLLDM without TS set  # Only first 16 registers should be loaded
    Register Should Be Equal        VPR  ${vpr_value}  message=VLLDM without TS set  # VPR should be loaded

    Populate FP Registers On f32    ${register_values}  # To restore registers s16-s31
    Execute Command                 cpu Step 8
    FP Registers Should Be Equal On f32  ${{ $register_values }}  message=VLLDM with TS set  # All registers should be loaded
    Register Should Be Equal        VPR  ${vpr_value}  message=VLLDM with TS set  # VPR should be loaded

    Execute Command                 cpu Step 2
    Execute Command                 sysbus WriteBytes [0xFF, 0xFF, 0xFF, 0xFF, 0xFF] ${{ $memory_address + $result_stride * 2 }}  # Write trash values to target address
    Execute Command                 cpu Step 1
    FP Registers Should Be Equal On f32  ${{ $register_values }}  message=VLLDM without LSP  # All registers should stay unchanged
    Register Should Be Equal        VPR  ${vpr_value}  message=VLLDM without LSP  # VPR should stay unchanged
