*** Variables ***
${GICR_TYPER}                       8
${GICR_ISENABLER0}                  0x10100

*** Keywords ***
Prepare Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    # The specific platform doesn't matter as long as it has GICv3 and more than one CPU
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r52_smp.repl

Write To Redistributor
    [Arguments]                     ${index}  ${reg}  ${val}  ${context}  ${size}=Double

    ${addr}=                        Evaluate  0xAF100000 + 0x20000 * ${index.strip()} + ${reg.strip()}
    Execute Command                 sysbus Write${size}Word ${addr} ${val} ${context}

Read From Redistributor
    [Arguments]                     ${index}  ${reg}  ${context}  ${size}=Double

    ${addr}=                        Evaluate  0xAF100000 + 0x20000 * ${index.strip()} + ${reg.strip()}
    ${val}=                         Execute Command  sysbus Read${size}Word ${addr} ${context}
    [Return]                        ${val}

Compare ${cpu} Id With Redistributor ${rdist}
    ${expected}=                    Execute Command  ${cpu} MultiprocessingId
    ${gicr_typer_val}=              Read From Redistributor  ${rdist}  ${GICR_TYPER}  ${cpu}  size=Quad
    ${gic_affinity}=                Evaluate  ${gicr_typer_val.strip()} >> 32
    ${result}=                      Evaluate  ${expected.strip()} == ${gic_affinity}
    [Return]                        ${result}

*** Test Cases ***
Only Our Redistributor Should Match Our Affinity
    Prepare Machine

    ${result}=                      Compare cpu Id With Redistributor 0
    Should Be True                  ${result}
    ${result}=                      Compare cpu Id With Redistributor 1
    Should Not Be True              ${result}

    ${result}=                      Compare cpu1 Id With Redistributor 1
    Should Be True                  ${result}
    ${result}=                      Compare cpu1 Id With Redistributor 0
    Should Not Be True              ${result}

Wriiting To Own Redistributor Shouldn't Affect Others
    Prepare Machine

    ${expected_our_gicr_isenabler0}=  Evaluate  0xffffffff
    ${expected_other_gicr_isenabler0}=  Evaluate  0x00000000

    Write To Redistributor          0  ${GICR_ISENABLER0}  ${expected_our_gicr_isenabler0}  cpu
    Write To Redistributor          1  ${GICR_ISENABLER0}  ${expected_other_gicr_isenabler0}  cpu1

    ${actual_our_gicr_isenabler0}=  Read From Redistributor  0  ${GICR_ISENABLER0}  cpu
    ${actual_other_gicr_isenabler0}=  Read From Redistributor  1  ${GICR_ISENABLER0}  cpu

    Should Be Equal As Integers     ${expected_our_gicr_isenabler0}  ${actual_our_gicr_isenabler0}
    Should Be Equal As Integers     ${expected_other_gicr_isenabler0}  ${actual_other_gicr_isenabler0}

Writing To Other Redistributor Shouldn't Affect Own
    Prepare Machine

    ${expected_our_gicr_isenabler0}=  Evaluate  0x00000000
    ${expected_other_gicr_isenabler0}=  Evaluate  0xffffffff

    Write To Redistributor          0  ${GICR_ISENABLER0}  ${expected_our_gicr_isenabler0}  cpu
    Write To Redistributor          1  ${GICR_ISENABLER0}  ${expected_other_gicr_isenabler0}  cpu

    ${actual_our_gicr_isenabler0}=  Read From Redistributor  0  ${GICR_ISENABLER0}  cpu
    ${actual_other_gicr_isenabler0}=  Read From Redistributor  1  ${GICR_ISENABLER0}  cpu1

    Should Be Equal As Integers     ${expected_our_gicr_isenabler0}  ${actual_our_gicr_isenabler0}
    Should Be Equal As Integers     ${expected_other_gicr_isenabler0}  ${actual_other_gicr_isenabler0}
