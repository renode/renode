*** Variables ***
${URI}                        @https://dl.antmicro.com/projects/renode
${BAYES_ELF}                  ${URI}/arm_bayes_example-s_533068-1b83380598c43c98e36196b0d3b6e5557c2a0b35
${CLASS_MARKS_ELF}            ${URI}/arm_class_marks_example-s_534536-d70b3e3e734a39133c11413daae2b0993d357032
${FIR_ELF}                    ${URI}/arm_fir_example-s_530876-a16180ffd6bddff383adbd5fdb38b32e7ebb89be
${MATRIX_ELF}                 ${URI}/arm_matrix_example-s_530856-9229a0ab3b3ad36b08ab55301753d3dd646a7a13
${REPL}                       SEPARATOR=\n
...                           """
...                           cpu: CPU.CortexM @ sysbus { cpuType: "cortex-m85"; nvic: nvic }
...                           nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { -> cpu@0 }
...                           rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000 }
...                           ram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x100000 }
...                           serial: UART.TrivialUart @ sysbus 0xA8000000
...                           """


*** Keywords ***
Create Machine
    [Arguments]                     ${ELF}

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL}
    Execute Command                 sysbus LoadELF ${ELF}

    Create Terminal Tester          sysbus.serial

*** Test Cases ***
Should Pass Matrix Test
    Create Machine                  ${MATRIX_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass FIR Test
    Create Machine                  ${FIR_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Generate Expected Values In Bayes Test
    Create Machine                  ${BAYES_ELF}
    Start Emulation

    Wait For Line On Uart           0
    Wait For Line On Uart           1
    Wait For Line On Uart           2

Should Generate Expected Values In Class Marks Test
    Create Machine                  ${CLASS_MARKS_ELF}
    Start Emulation

    Wait For Line On Uart           mean = 212.300003, std = 50.912827

