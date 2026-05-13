*** Variables ***
${VEXRISCV}                         SEPARATOR=\n
...                                 """
...                                 ram: Memory.MappedMemory @ sysbus 0x10000000
...                                 ${SPACE*4}size: 0x40000
...
...                                 cpu: CPU.VexRiscv @ sysbus
...                                 ${SPACE*4}cpuType: "rv32imac_zicsr_zifencei"
...
...                                 uart: UART.LiteX_UART @ sysbus 0xE0000600
...                                 ${SPACE*4}-> cpu@2
...
...                                 timer0: Timers.LiteX_Timer_CSR32 @ sysbus 0xE0000A00
...                                 ${SPACE*4}frequency: 100000000
...                                 ${SPACE*4}-> cpu@1
...
...                                 lpddr4_ctrl: MemoryControllers.LPDDR4_DRAMController @ sysbus 0x83000000
...                                 """

${ELF}                              https://dl.antmicro.com/projects/renode/zephyr.elf-s_925008-da6ed478788596ac7424838f44290090b47a2a45

*** Keywords ***
Create VexRiscV Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${VEXRISCV}

*** Test Cases ***
Should Successfully Train
    Create VexRiscV Machine
    Create Terminal Tester          sysbus.uart
    Execute Command                 sysbus LoadELF @${ELF}

    Wait For Line On Uart           Memory training finished!  includeUnfinishedLine=True
