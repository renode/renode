*** Keywords ***
Create Machine
    [Arguments]                     ${isa}
    ${isa_base}=                    Convert To Lower Case  ${isa}[0:4]
    IF  "${isa_base}" == "rv32"
        ${bits}=                        Set Variable  32
    ELSE IF  "${isa_base}" == "rv64"
        ${bits}=                        Set Variable  64
    ELSE
        Fail                            Invalid ISA name: ${isa}
    END

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bits} @ sysbus { cpuType: \\"${isa}\\" }"

*** Test Cases ***
Should Create CPUs With Supported ISAs
    [Template]                      Create Machine
    RV32I_Smepmp
    RV32I_Sscofpmf
    RV32I_V
    RV32I_Zvfh
    RV32I_Zve32x
    RV32I_Zve32f
    RV32I_Zve64x
    RV32I_Zve64f
    RV32I_Zve64d

Should Fail On Unsupported ISA
    Run Keyword And Expect Error    *Undefined instructions set extension*  Create Machine  RV32GC_invalid_ISA
