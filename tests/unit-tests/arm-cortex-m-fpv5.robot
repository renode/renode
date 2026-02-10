*** Settings ***
Test Setup                          Create Machine and Start FPU

*** Variables ***
${START_ADDRESS}                    0x0
${PLATFORM}                         @platforms/cpus/renesas-r7fa8m1a.repl

*** Keywords ***
Load Program And Execute
    [Arguments]                     ${ASSEMBLY}  ${STEPS}
    Execute Command                 cpu AssembleBlock ${START_ADDRESS} """${ASSEMBLY}"""
    Execute Command                 cpu PC ${START_ADDRESS}
    Execute Command                 cpu Step ${STEPS}

Create Machine and Start FPU
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

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

        Execute Command                 cpu SetRegister "fpscr" 0x400000

        ${program}=                     Catenate  SEPARATOR=\n
        ...                             vmov.${precision} ${register}0, \#${value}
        ...                             vrintm.${precision} ${register}3, ${register}0  # Round toward minus infinity
        ...                             vrintr.${precision} ${register}1, ${register}0
        ...                             vrintx.${precision} ${register}2, ${register}0
        Load Program And Execute        ASSEMBLY=${program}  STEPS=4

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
