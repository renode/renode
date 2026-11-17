*** Variables ***
${MCAUSE_BREAKPOINT}          3
${UART}                       sysbus.htif
${SCRIPT_ROT13}               @scripts/single-node/veer_el2-tock.resc

*** Test Cases ***
Should Run Tock Rot13 Sample
    Execute Command           include ${SCRIPT_ROT13}
    Create Terminal Tester    ${UART}
    Wait For Line On Uart     12: Uryyb Jbeyq!
    Wait For Line On Uart     12: Hello World!

Should Update MTVAL On EBREAK
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescription @platforms/cpus/tock_veer_el2_sim.repl
    Execute Command               using sysbus

    # Any value except ${break_pc} is ok here.
    Execute Command               cpu MTVAL 0x0

    # Add ebreak code at 0x8000 and step, PC is nonzero to make sure MTVAL contains PC after break.
    ${break_pc}=  Set Variable    0x8000
    Execute Command               cpu PC ${break_pc}
    Execute Command               cpu AssembleBlock ${break_pc} "ebreak"
    Execute Command               cpu Step

    # CPU should jump to MTVEC with MCAUSE for breakpoint and MTVAL set to PC.
    ${mtvec}=  Execute Command    cpu MTVEC
    Register Should Be Equal      PC      ${mtvec}
    Register Should Be Equal      MCAUSE  ${MCAUSE_BREAKPOINT}
    Register Should Be Equal      MTVAL   ${break_pc}

