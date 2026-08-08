*** Variables ***
${BOOT_MSG}         DRAM: 1 GiB
${SCU_UNLOCK}       0x1688A8A8
${SDMC_UNLOCK}      0xFC600309

*** Keywords ***
Create And Boot AST2600
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl
    Execute Command         sysbus LoadBinary @tests/peripherals/Aspeed/firmware/ast2600_spl_stub.bin 0x60000000
    Execute Command         sysbus LoadBinary @tests/peripherals/Aspeed/firmware/ast2600_spl_stub.bin 0x0
    Execute Command         cpu0 PC 0x0
    Create Terminal Tester  sysbus.uart5    timeout=5

*** Test Cases ***
SPL Should Print DRAM Size
    [Documentation]         Boot SPL stub and verify it prints "DRAM: 1 GiB"
    [Tags]                  aspeed  spl  boot
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}

SPL Should Reach WFI After Boot
    [Documentation]         After printing boot message, CPU should halt (WFI)
    [Tags]                  aspeed  spl  boot
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    Execute Command         pause
    ${pc}=                  Execute Command    cpu0 PC
    ${pc_val}=              Evaluate    int(str(${pc.strip()}), 0)
    Should Be True          ${pc_val} >= 0x6C and ${pc_val} <= 0x74

SPL Should Unlock SCU
    [Documentation]         After boot, SCU protection key should show unlocked
    [Tags]                  aspeed  spl  boot  scu
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    ${prot}=                Execute Command    sysbus ReadDoubleWord 0x1E6E2000
    Should Be Equal As Numbers  ${prot.strip()}  ${SCU_UNLOCK}

SPL Should Unlock SDMC
    [Documentation]         After boot, SDMC protection should be unlocked
    [Tags]                  aspeed  spl  boot  sdmc
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    ${prot}=                Execute Command    sysbus ReadDoubleWord 0x1E6E0000
    # SDMC returns 0x01 (QEMU PROT_UNLOCKED) not the raw key
    Should Not Be Equal As Numbers  ${prot.strip()}  0x0

SPL Should Disable WDT1
    [Documentation]         SPL should disable watchdog 1 during early boot
    [Tags]                  aspeed  spl  boot  wdt
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    ${ctrl}=                Execute Command    sysbus ReadDoubleWord 0x1E78500C
    ${ctrl_val}=            Evaluate    int(str(${ctrl.strip()}), 0) & 1
    Should Be Equal As Numbers  ${ctrl_val}  0

SPL Should Write DRAM Test Pattern
    [Documentation]         SPL writes 0xDEADBEEF to DRAM base and verifies read-back
    [Tags]                  aspeed  spl  boot  dram
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    ${val}=                 Execute Command    sysbus ReadDoubleWord 0x80000000
    Should Be Equal As Numbers  ${val.strip()}  0xDEADBEEF

SPL Full Boot Sequence
    [Documentation]         Comprehensive: all peripherals exercised during boot
    [Tags]                  aspeed  spl  boot  integration
    Create And Boot AST2600
    Start Emulation
    Wait For Line On Uart   ${BOOT_MSG}
    ${scu}=                 Execute Command    sysbus ReadDoubleWord 0x1E6E2000
    Should Be Equal As Numbers  ${scu.strip()}  ${SCU_UNLOCK}
    ${sdmc}=                Execute Command    sysbus ReadDoubleWord 0x1E6E0000
    # SDMC returns 0x01 (PROT_UNLOCKED) not raw key
    Should Not Be Equal As Numbers  ${sdmc.strip()}  0x0
    ${dram}=                Execute Command    sysbus ReadDoubleWord 0x80000000
    Should Be Equal As Numbers  ${dram.strip()}  0xDEADBEEF
    ${wdt}=                 Execute Command    sysbus ReadDoubleWord 0x1E78500C
    ${wdt_val}=             Evaluate    int(str(${wdt.strip()}), 0) & 1
    Should Be Equal As Numbers  ${wdt_val}  0
