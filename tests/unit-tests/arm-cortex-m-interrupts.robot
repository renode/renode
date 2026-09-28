*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32f4.repl

*** Test Cases ***
Should Wake Up From WFE When SEVONPEND Is Set
    Create Machine

    ${target_address}=              Set Variable  0x20001000
    ${target_data}=                 Set Variable  0xDEADBEEF
    ${start_address}=               Set Variable  0x20000000

    Store Double Word               0xE000ED10  0x10  # Set SCR.SEVONPEND

    Execute Command                 cpu PC ${start_address}
    Execute Command                 cpu SP 0x20040000

    Execute Command                 cpu SetRegister "R0" ${target_address}
    Execute Command                 cpu SetRegister "R1" ${target_data}

    ${assembly}=                    Catenate  SEPARATOR=\n
    ...                             wfe
    ...                             str r1, [r0]
    ...                             b .
    Execute Command                 cpu AssembleBlock ${start_address} """${assembly}"""

    # Start emulation to get into WFE
    Execute Command                 emulation RunFor "0.001"
    Memory Should Be Equal          ${target_address}  0x0  DoubleWord

    # CPU should wake up now
    Execute Command                 sysbus.nvic OnGPIO 5 true

    Memory Should Be Equal          ${target_address}  ${target_data}  DoubleWord  timeout=1
