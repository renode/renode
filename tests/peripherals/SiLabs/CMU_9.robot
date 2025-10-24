*** Variables ***
${REPL_STRING}=                 SEPARATOR=
...  """                                                                              ${\n}
...  cmu: Miscellaneous.SiLabs.Cmu_9                   @ sysbus <0x4080C000, +0x4000> ${\n}
...  hfxo: Miscellaneous.SiLabs.Hfxo_7                 @ sysbus <0x40104000, +0x4000> ${\n}
...  hfrcodpll: Miscellaneous.SiLabs.SiLabs_HFRCO_3    @ sysbus <0x40818000, +0x4000> ${\n}
...  hfrcoem23: Miscellaneous.SiLabs.SiLabs_HFRCO_3    @ sysbus <0x40100000, +0x4000> ${\n}
...  lfxo: Miscellaneous.SiLabs.SiLabs_LFXO_2          @ sysbus <0x40828000, +0x4000> ${\n}
...  lfrco: Miscellaneous.SiLabs.SiLabs_LFRCO_4        @ sysbus <0x4082C000, +0x4000> ${\n}
...  dpll: Miscellaneous.SiLabs.SiLabs_DPLL_1 @ sysbus <0x40824000, +0x4000>          ${\n}
...  socpll0: Miscellaneous.SiLabs.Socpll_3  @ sysbus <0x40800000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 0                                                            ${\n}
...  socpll1: Miscellaneous.SiLabs.Socpll_3  @ sysbus <0x40804000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 1                                                            ${\n}
...  socpll2: Miscellaneous.SiLabs.Socpll_3  @ sysbus <0x40808000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 2                                                            ${\n}
...  perpll0: Miscellaneous.SiLabs.Perpll_1  @ sysbus <0x408F8000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 0                                                            ${\n}
...  perpll1: Miscellaneous.SiLabs.Perpll_1  @ sysbus <0x408FC000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 1                                                            ${\n}
...  """
# Registers
${CTRL_REG}                  0x4080C004
${STATUS_REG}                0x4080C008
${LOCK_REG}                  0x4080C010
${WDOGLOCK_REG}              0x4080C014
${SYSCLKCTRL_REG}            0x4080C070
${EM01GRPACLKCTRL_REG}       0x4080C120
${EM01GRPCCLKCTRL_REG}       0x4080C128
${EM23GRPACLKCTRL_REG}       0x4080C140
${EM4GRPACLKCTRL_REG}        0x4080C160
${EUSART0CLKCTRL_REG}        0x4080C220
${PCNT0CLKCTRL_REG}          0x4080C270
${HFXO0LFCLKCTRL_REG}        0x4080C29C
${EM01GRPDCLKCTRL_REG}       0x4080C2A8
${I2C0CLKCTRL_REG}           0x4080C2AC
${CLKENHV_REG}               0x4080C2B4
${CAN0CLKCTRL_REG}           0x4080C320
${PERPLL0CLKCTRL_REG}        0x4080C514
${PERPLL1CLKCTRL_REG}        0x4080C518
${TIMER0CLKCTRL_REG}         0x4080C550
${HFRCO0CLKCTRL_REG}         0x4080C57C
${HFRCOEM23CLKCTRL_REG}      0x4080C580
${HFXO0CLKCTRL_REG}          0x4080C584
${LFRCOCLKCTRL_REG}          0x4080C58C
${BURTCCLKCTRL_REG}          0x4080C5A0
${SOCPLL0CLKCTRL_REG}        0x4080C5B8
${SOCPLL1CLKCTRL_REG}        0x4080C5E8
${SOCPLL2CLKCTRL_REG}        0x4080C63C
${LFXOCLKCTRL_REG}           0x4080C65C

${HFXO0_CTRL_REG}            0x40104030
${HFXO0_STATUS_REG}          0x40104068
${HFXO0_LOCK_REG}            0x40104080
${HFRCODPLL_CTRL_REG}        0x40818004
${HFRCODPLL_STATUS_REG}      0x4081800C
${HFRCODPLL_LOCK_REG}        0x4081801C
${HFRCOEM23_CTRL_REG}        0x40100004
${HFRCOEM23_STATUS_REG}      0x4010000C
${HFRCOEM23_LOCK_REG}        0x4010001C
${LFXO_CTRL_REG}             0x40828004
${LFXO_STATUS_REG}           0x40828010
${LFXO_LOCK_REG}             0x40828024
${LFRCO_CTRL_REG}            0x4082C004
${LFRCO_STATUS_REG}          0x4082C008
${LFRCO_LOCK_REG}            0x4082C020
${SOCPLL0_CTRL_REG}          0x40800004
${SOCPLL0_STATUS_REG}        0x40800020
${SOCPLL0_LOCK_REG}          0x4080002C
${SOCPLL1_CTRL_REG}          0x40804004
${SOCPLL1_STATUS_REG}        0x40804020
${SOCPLL1_LOCK_REG}          0x4080402C
${SOCPLL2_CTRL_REG}          0x40808004
${SOCPLL2_STATUS_REG}        0x40808020
${SOCPLL2_LOCK_REG}          0x4080802C
${PERPLL0_CTRL_REG}          0x408F8004
${PERPLL0_STATUS_REG}        0x408F8018
${PERPLL0_LOCK_REG}          0x408F8024
${PERPLL1_CTRL_REG}          0x408FC004
${PERPLL1_STATUS_REG}        0x408FC018
${PERPLL1_LOCK_REG}          0x408FC024

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}

*** Test Cases ***
INIT HFXO FOR EM01GRPA WITH TIMER0
    Create machine
    # Enable clock branch for HFXO and LFRCO
    Execute Command               sysbus.cmu WriteDoubleWord ${HFXO0CLKCTRL_REG} 0x1
    Execute Command               sysbus.cmu WriteDoubleWord ${LFRCOCLKCTRL_REG} 0x1
    # Choose HFXO for EM01GRPA
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPACLKCTRL_REG} 0x2
    # Unlock HFXO
    Execute Command               sysbus.lfxo WriteDoubleWord ${HFXO0_LOCK_REG} 0x580E
    # Set HFXO LF CLK to LFRCO
    Execute Command               sysbus.cmu WriteDoubleWord ${HFXO0LFCLKCTRL_REG} 0x2
    # Disable HFXO
    Execute Command               sysbus.hfxo WriteDoubleWord ${HFXO0_CTRL_REG} 0x1000000
    ${read_val}=                  Execute Command  sysbus.hfxo ReadDoubleWord ${HFXO0_STATUS_REG}
    # COREBIASOPTRDY should be set
    Should Be Equal As Integers   ${read_val}  0x10
    # Force enable HFXO
    Execute Command               sysbus.hfxo WriteDoubleWord ${HFXO0_CTRL_REG} 0x10000
    # RDY, COREBIASOPTRDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.hfxo ReadDoubleWord ${HFXO0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10011
    # On demand HFXO
    Execute Command               sysbus.hfxo WriteDoubleWord ${HFXO0_CTRL_REG} 0x0
    # Enable clock branch TIMER0
    Execute Command               sysbus.cmu WriteDoubleWord ${TIMER0CLKCTRL_REG} 0x1
    # RDY, COREBIASOPTRDY, ENS and HWREQ should be set
    ${read_val}=                  Execute Command  sysbus.hfxo ReadDoubleWord ${HFXO0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x30011
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${TIMER0CLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPACLKCTRL_REG} 0x1
    Execute Command               sysbus.cmu WriteDoubleWord ${HFXO0LFCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${LFRCOCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${HFXO0CLKCTRL_REG} 0x0

INIT HFRCODPLL FOR EM01GRPC WITH EUSART0
    Create machine
    # Enable clock branch HFRCODPLL 
    Execute Command               sysbus.cmu WriteDoubleWord ${HFRCO0CLKCTRL_REG} 0x1
    # Choose HFRCODPLL for EM01GRPC
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPCCLKCTRL_REG} 0x1
    # Unlock HFRCODPLL
    Execute Command               sysbus.hfrcodpll WriteDoubleWord ${HFRCODPLL_LOCK_REG} 0x8195
    # Disable HFRCODPLL
    Execute Command               sysbus.hfrcodpll WriteDoubleWord ${HFRCODPLL_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.hfrcodpll ReadDoubleWord ${HFRCODPLL_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Force enable HFRCODPLL
    Execute Command               sysbus.hfrcodpll WriteDoubleWord ${HFRCODPLL_CTRL_REG} 0x1
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.hfrcodpll ReadDoubleWord ${HFRCODPLL_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # On demand HFRCODPLL
    Execute Command               sysbus.hfrcodpll WriteDoubleWord ${HFRCODPLL_CTRL_REG} 0x0
    # Enable clock branch EUSART0 and select EM01GRPC
    Execute Command               sysbus.cmu WriteDoubleWord ${EUSART0CLKCTRL_REG} 0x101
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.hfrcodpll ReadDoubleWord ${HFRCODPLL_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${EUSART0CLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPCCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${HFRCO0CLKCTRL_REG} 0x0

INIT HFRCOEM23 FOR EM01GRPD WITH I2C0
    Create machine
    # Enable clock branch HFRCOEM23 
    Execute Command               sysbus.cmu WriteDoubleWord ${HFRCOEM23CLKCTRL_REG} 0x1
    # Choose HFRCOEM23 for EM01GRPD
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPDCLKCTRL_REG} 0x1
    # Unlock HFRCOEM23
    Execute Command               sysbus.hfrcoem23 WriteDoubleWord ${HFRCOEM23_LOCK_REG} 0x8195
    # Disable HFRCOEM23
    Execute Command               sysbus.hfrcoem23 WriteDoubleWord ${HFRCOEM23_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.hfrcoem23 ReadDoubleWord ${HFRCOEM23_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Force enable HFRCOEM23
    Execute Command               sysbus.hfrcoem23 WriteDoubleWord ${HFRCOEM23_CTRL_REG} 0x1
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.hfrcoem23 ReadDoubleWord ${HFRCOEM23_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # On demand HFRCOEM23
    Execute Command               sysbus.hfrcoem23 WriteDoubleWord ${HFRCOEM23_CTRL_REG} 0x0
    # Enable clock branch I2C0 and select EM01GRPD
    Execute Command               sysbus.cmu WriteDoubleWord ${I2C0CLKCTRL_REG} 0x101
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.hfrcoem23 ReadDoubleWord ${HFRCOEM23_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${I2C0CLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${EM01GRPDCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${HFRCOEM23CLKCTRL_REG} 0x0

INIT LFRCO FOR EM23GRPA WITH PCNT0
    Create machine
    # Enable clock branch LFRCO 
    Execute Command               sysbus.cmu WriteDoubleWord ${LFRCOCLKCTRL_REG} 0x1
    # Choose LFRCO for EM23GRPA
    Execute Command               sysbus.cmu WriteDoubleWord ${EM23GRPACLKCTRL_REG} 0x1
    # Unlock LFRCO
    Execute Command               sysbus.lfrco WriteDoubleWord ${LFRCO_LOCK_REG} 0xF93
    # Disable LFRCO
    Execute Command               sysbus.lfrco WriteDoubleWord ${LFRCO_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.lfrco ReadDoubleWord ${LFRCO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Force enable LFRCO
    Execute Command               sysbus.lfrco WriteDoubleWord ${LFRCO_CTRL_REG} 0x1
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.lfrco ReadDoubleWord ${LFRCO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # On demand LFRCO
    Execute Command               sysbus.lfrco WriteDoubleWord ${LFRCO_CTRL_REG} 0x0
    # Enable clock branch PCNT0
    Execute Command               sysbus.cmu WriteDoubleWord ${PCNT0CLKCTRL_REG} 0x101
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.lfrco ReadDoubleWord ${LFRCO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${PCNT0CLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${EM23GRPACLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${LFRCOCLKCTRL_REG} 0x0

INIT LFXO FOR EM4GRPA WITH BURTC
    Create machine
    # Enable clock branch LFXO and BURTC
    Execute Command               sysbus.cmu WriteDoubleWord ${LFXOCLKCTRL_REG} 0x1
    # Choose LFXO for EM4GRPA
    Execute Command               sysbus.cmu WriteDoubleWord ${EM4GRPACLKCTRL_REG} 0x2
    # Unlock LFXO
    Execute Command               sysbus.lfxo WriteDoubleWord ${LFXO_LOCK_REG} 0x1A20
    # Disable LFXO
    Execute Command               sysbus.lfxo WriteDoubleWord ${LFXO_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.lfxo ReadDoubleWord ${LFXO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Force enable LFXO
    Execute Command               sysbus.lfxo WriteDoubleWord ${LFXO_CTRL_REG} 0x1
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.lfxo ReadDoubleWord ${LFXO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # On demand LFXO
    Execute Command               sysbus.lfxo WriteDoubleWord ${LFXO_CTRL_REG} 0x0
    # Enable clock branch BURTC
    Execute Command               sysbus.cmu WriteDoubleWord ${BURTCCLKCTRL_REG} 0x1
    # RDY and ENS should be set
    ${read_val}=                  Execute Command  sysbus.lfxo ReadDoubleWord ${LFXO_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x10001
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${BURTCCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${EM4GRPACLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${LFXOCLKCTRL_REG} 0x0

INIT SOCPLL0 FOR SYSCLK
    Create machine
    # Enable clock branch SOCPLL0 
    Execute Command               sysbus.cmu WriteDoubleWord ${SOCPLL0CLKCTRL_REG} 0x1
    # Unlock SOCPLL0
    Execute Command               sysbus.socpll0 WriteDoubleWord ${SOCPLL0_LOCK_REG} 0x81A6
    # Disable SOCPLL0
    Execute Command               sysbus.socpll0 WriteDoubleWord ${SOCPLL0_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.socpll0 ReadDoubleWord ${SOCPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x400
    # Force enable SOCPLL0
    Execute Command               sysbus.socpll0 WriteDoubleWord ${SOCPLL0_CTRL_REG} 0x1
    # RDY, PLLLOCK and ENS should be set
    ${read_val}=                  Execute Command  sysbus.socpll0 ReadDoubleWord ${SOCPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x503
    ${read_val}=                  Execute Command  sysbus.socpll1 ReadDoubleWord ${SOCPLL1_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x400
    ${read_val}=                  Execute Command  sysbus.socpll2 ReadDoubleWord ${SOCPLL2_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x400
    # On demand SOCPLL0
    Execute Command               sysbus.socpll0 WriteDoubleWord ${SOCPLL0_CTRL_REG} 0x0
    # Choose SOCPLL0 for SYSCLK
    Execute Command               sysbus.cmu WriteDoubleWord ${SYSCLKCTRL_REG} 0x5
    # RDY, PLLLOCK and ENS should be set
    ${read_val}=                  Execute Command  sysbus.socpll0 ReadDoubleWord ${SOCPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x503
    ${read_val}=                  Execute Command  sysbus.socpll1 ReadDoubleWord ${SOCPLL1_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x400
    ${read_val}=                  Execute Command  sysbus.socpll2 ReadDoubleWord ${SOCPLL2_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x400
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${SYSCLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${SOCPLL0CLKCTRL_REG} 0x0

INIT PERPLL0 FOR CAN0
    Create machine
    # Enable clock branch PERPLL0 
    Execute Command               sysbus.cmu WriteDoubleWord ${PERPLL0CLKCTRL_REG} 0x1
    # Unlock PERPLL0
    Execute Command               sysbus.perpll0 WriteDoubleWord ${PERPLL0_LOCK_REG} 0x81A6
    # Disable PERPLL0
    Execute Command               sysbus.perpll0 WriteDoubleWord ${PERPLL0_CTRL_REG} 0x2
    ${read_val}=                  Execute Command  sysbus.perpll0 ReadDoubleWord ${PERPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Force enable PERPLL0
    Execute Command               sysbus.perpll0 WriteDoubleWord ${PERPLL0_CTRL_REG} 0x1
    # RDY, PLLLOCK and ENS should be set
    ${read_val}=                  Execute Command  sysbus.perpll0 ReadDoubleWord ${PERPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x103
    ${read_val}=                  Execute Command  sysbus.perpll1 ReadDoubleWord ${PERPLL1_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # On demand PERPLL0
    Execute Command               sysbus.perpll0 WriteDoubleWord ${PERPLL0_CTRL_REG} 0x0
    # Choose PERPLL0 for CAN0
    Execute Command               sysbus.cmu WriteDoubleWord ${CAN0CLKCTRL_REG} 0x101
    # RDY, PLLLOCK and ENS should be set
    ${read_val}=                  Execute Command  sysbus.perpll0 ReadDoubleWord ${PERPLL0_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x103
    ${read_val}=                  Execute Command  sysbus.perpll1 ReadDoubleWord ${PERPLL1_STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    # Teardown test
    Execute Command               sysbus.cmu WriteDoubleWord ${CAN0CLKCTRL_REG} 0x0
    Execute Command               sysbus.cmu WriteDoubleWord ${PERPLL0CLKCTRL_REG} 0x0


