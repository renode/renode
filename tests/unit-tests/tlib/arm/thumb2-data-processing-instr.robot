*** Variables ***
${ELF}                              https://dl.antmicro.com/projects/renode/cortex-m-thumb2-data-processing-instr-test.elf-s_17032-6adacbffaba09470a834f59b7e0ba21319b546c2

${REPL}                             SEPARATOR=\n
...                                 """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x40000
...                                 nvic0: IRQControllers.NVIC @ {
...                                 ${SPACE*4}sysbus new Bus.BusPointRegistration { address: 0xe000e000; cpu: cpu0 }
...                                 }
...                                 ${SPACE*4}-> cpu0@0
...                                 cpu0: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m85"
...                                 ${SPACE*4}nvic: nvic0
...                                 """

*** Test Cases ***
Should Run All Instructions
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL}
    Execute Command                 sysbus LoadELF @${ELF}

    Execute Command                 emulation RunFor "1"
    ${run_result_addr}=             Execute Command  sysbus GetSymbolAddress "run_result"
    ${run_result}=                  Execute Command  sysbus ReadWord ${run_result_addr}
    
    # If all instruction tests pass - 0xFFFF value is put at run_result address
    # otherwise number of line in code which invoked assert
    Should Be Equal As Numbers      ${run_result}  0xFFFF  Error in line ${run_result}
