*** Variables ***
${SCB_SYST_CSR}                     0xE000E010
${SCB_SYST_RVR}                     0xE000E014
${SCB_SYST_CVR}                     0xE000E018

${SYSTICK_FREQUENCY}                100
${SYSTICK_RELOAD_VALUE}             10

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32f4.repl

Verify SysTick Working
    # Check if current value got updated to reload value
    Memory Should Be Equal          ${SCB_SYST_CVR}  ${SYSTICK_RELOAD_VALUE}  DoubleWord

    # Check just before SysTick going to 0
    Execute Command                 emulation RunFor "0.09"
    Memory Should Be Equal          ${SCB_SYST_CVR}  1  DoubleWord

    # Check if SysTick returned to the original value
    Execute Command                 emulation RunFor "0.01"
    Memory Should Be Equal          ${SCB_SYST_CVR}  ${SYSTICK_RELOAD_VALUE}  DoubleWord

    # Check if SysTick started counting down again
    Execute Command                 emulation RunFor "0.01"
    Memory Should Be Equal          ${SCB_SYST_CVR}  ${{ ${SYSTICK_RELOAD_VALUE} - 1}}  DoubleWord

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

NVIC Base Priority Mask Setting Should Not Survive Reset
    Create Machine
    Execute Command                 allowPrivates true
    Execute Command                 cpu SetRegister "BasePri" 0x50
    ${reg_value}=                   Execute Command  cpu GetRegister "BasePri"
    # Is expected to return the Base Priority Mask with this setup
    ${actual_value}=                Execute Command  nvic GetPriorityBoost false
    Should Be Equal As Integers     ${reg_value}  ${actual_value}

    Execute Command                 machine Reset
    ${post_reset_value}=            Execute Command  nvic GetPriorityBoost false
    Should Not Be Equal As Integers  ${actual_value}  ${post_reset_value}

Should Count Down SysTick With Reload Set Before Reset
    Create Machine

    Execute Command                 nvic Frequency ${SYSTICK_FREQUENCY}
    Store Double Word               ${SCB_SYST_CSR}  0
    Store Double Word               ${SCB_SYST_CVR}  0
    Store Double Word               ${SCB_SYST_RVR}  ${SYSTICK_RELOAD_VALUE}
    Store Double Word               ${SCB_SYST_CSR}  0x5

    Verify SysTick Working

Should Count Down SysTick With Reload Set After Reset
    Create Machine

    Execute Command                 nvic Frequency ${SYSTICK_FREQUENCY}
    Store Double Word               ${SCB_SYST_CSR}  0
    Store Double Word               ${SCB_SYST_RVR}  ${SYSTICK_RELOAD_VALUE}
    Store Double Word               ${SCB_SYST_CVR}  0
    Store Double Word               ${SCB_SYST_CSR}  0x5

    Verify SysTick Working
