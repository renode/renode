*** Variables ***
${UART}                         sysbus.mmuart0
${SCRIPT}                       ${CURDIR}/../../scripts/single-node/polarfire-soc.resc

*** Keywords ***
Prepare Machine
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/polarfire-soc.repl
    Execute Command           sysbus LoadELF ${binary}

Run Should Ignore Writing Other Values Test
    [Arguments]                 ${path}
    Execute Command             $bin = ${path}
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Wait For Line On Uart       H0 MVRP PLIC
    Wait For Line On Uart       H0 timeout PLIC

    Wait For Line On Uart       The system will reset after WD0 Times out.


*** Test Cases ***
Should Fire NMI When Writing Any Value Into Forbidden Region When Forbidden Region Is Enabled
    Execute Command             $bin = @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-a.elf-s_3353960-dd65a2a6d435d49509523cf68058af7027c69f02
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Create Log Tester           0
    Execute Command             logLevel -1
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Wait For Line On Uart       H0 timeout PLIC

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Should Not Be In Log        Switching state to RefreshRegion.
    Should Not Be In Log        Refreshing watchdog.


Should Refresh Watchdog By Writing Refresh Key Into Refresh Region When Forbidden Region Is Enabled
    Execute Command             $bin = @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-b.elf-s_3353976-d0a8861250d15dbba1e25fb51797e72f82460453
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Create Log Tester           0
    Execute Command             logLevel -1
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Wait For Line On Uart       H0 MVRP PLIC
    Wait For Line On Uart       H0 MVRP Local

    Should Not Be In Log        Watchdog reset triggered!


Should Ignore Writing Other Values Into Refresh Region When Forbidden Region Is Enabled
    Execute Command             $bin = @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-c.elf-s_3353976-2227f483cde453795dad468e3913e1a9a8dde7dc
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Create Log Tester           0
    Execute Command             logLevel -1
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Wait For Line On Uart       H0 MVRP PLIC
    Wait For Line On Uart       H0 timeout PLIC

    Should Not Be In Log        Refreshing watchdog.


Should Refresh Watchdog By Writing Refresh Key Into Forbidden Region When Forbidden Region Is Disabled
    Execute Command             $bin = @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-d-forbidden.elf-s_3353960-d197eb0f96c99c4ae244c315875d6d353d2c43ad
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Create Log Tester           0
    Execute Command             logLevel -1
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.

    Wait For Log Entry          Switching state to ForbiddenRegion.
    Should Not Be In Log        Switching state to RefreshRegion.


Should Refresh Watchdog By Writing Refresh Key Into Refresh Region When Forbidden Region Is Disabled
    Execute Command             $bin = @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-d-refresh.elf-s_3353976-f3fd8998a7f9ae641fd786dd36b83b9074189010
    Execute Script              ${SCRIPT}
    Create Terminal Tester      ${UART}
    Create Log Tester           0
    Execute Command             logLevel -1
    Start Emulation

    Wait For Line On Uart       The system will reset after WD0 Times out.
    Wait For Line On Uart       H0 MVRP PLIC
    Wait For Line On Uart       H0 MVRP Local

    Wait For Log Entry          Refreshing watchdog.
    Should Not Be In Log        Watchdog reset triggered!


Should Ignore Writing Other Values Into Forbidden Region When Forbidden Region Is Disabled
    Run Should Ignore Writing Other Values Test                    @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-e-forbidden.elf-s_3353960-2f4c36d3170f74f57c7b7f18823ad1c6d2f1f0a4


Should Ignore Writing Other Values Into Refresh Region When Forbidden Region Is Disabled
    Run Should Ignore Writing Other Values Test                    @https://dl.antmicro.com/projects/renode/mpfs-watchdog-interrupt_case-e-refresh.elf-s_3353960-c66342498de3d6efc69d0b338fba83322385d77c
