*** Keywords ***
Create RISC-V With ISA String
    [Arguments]                     ${ISAString}
    Execute Command                 mach create
    Execute Command                 logLevel 0
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"${ISAString}\\"}"

Create RISC-V64 With ISA String
    [Arguments]                     ${ISAString}
    Execute Command                 mach create
    Execute Command                 logLevel 0
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"${ISAString}\\"}"

*** Test Cases ***
Should Parse All Valid ISA Strings
    [Template]                      Create RISC-V With ISA String
    RV32G
    rv32gc
    rv32gc
    RV32GC
    rv32gc_xandes
    RV32GC_Xandes
    RV32GC_Zicsr_Zifencei
    RV32G_V
    rv32ia_zicsr_zifencei
    RV32IM
    RV32IMAC
    RV32IMACB_Zicsr_Zifencei
    RV32IMACFD_Zicsr
    RV32IMACFD_Zicsr_Zifencei
    rv32imac_zicsr
    RV32_IMACZicsr_Zifencei
    RV32IMAC_Zicsr_Zifencei
    RV32IMACZicsr_Zifencei
    rv32imafc_zifencei
    rv32imafdcg
    RV32IMAFDC_Zicsr
    RV32IMAFDC_Zicsr_Zifencei
    RV32IMAF_Zicsr_Zifencei
    rv32ima_zicsr_zifencei
    RV32IMC
    rv32imcb_zicsr_zifencei
    rv32imc_zicsr
    rv32imc_zicsr_zifencei
    RV32IMC_Zicsr_Zifencei_Zbs
    RV32IM_Zicsr
    rv32im_zicsr_zifencei
    RV32IZifencei_Xandes

Should Handle Both 32 And 64 Bit Versions
    Create RISC-V With ISA String   RV32IMAFDC_Zicsr_Zifencei
    Create RISC-V64 With ISA String  RV64IMAFDC_Zicsr_Zifencei
