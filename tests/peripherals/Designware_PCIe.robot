*** Variables ***
${PROJECT_URL}                      https://dl.antmicro.com/projects/renode

${PROMPT}                           \#${SPACE}
${UART}                             sysbus.uart0

${EXPECTED_BAR_LAYOUT}
...                                 -------------------------------------------------------------------${\n}
...                                 |Number|Range                   |Peripheral                       |${\n}
...                                 -------------------------------------------------------------------${\n}
...                                 |0     |<0x00010000, 0x000101FF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 |1     |<0x00010200, 0x000103FF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 |2     |<0x00010400, 0x000105FF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 |3     |<0x00010600, 0x000107FF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 |4     |<0x00010800, 0x000109FF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 |5     |<0x00010A00, 0x00010BFF>|ARM Cortex-A53 with PCIe.pcieMem1|${\n}
...                                 -------------------------------------------------------------------

*** Keywords ***
Load Platform
    Execute Command                 i @scripts/single-node/cortex-a53-linux-pcie.resc

    Create Terminal Tester          ${UART}  defaultPauseEmulation=True

Boot Linux And Login
    # Wait for Linux to boot up and log into the shell
    Wait For Prompt On Uart         buildroot login:  timeout=25
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}

*** Test Cases ***
Should Initialize Controller
    Load Platform

    Wait For Line On Uart           dw-pcie 10000000.pcie: PCIe Gen.6 x16 link up                timeout=15
    Wait For Line On Uart           dw-pcie 10000000.pcie: PCI host bridge to bus 0000:00        timeout=15

    Provides                        driver-loaded

Should Assign BARs
    Requires                        driver-loaded

    Wait For Line On Uart           pci 0000:01:00.0: BAR 0 [mem 0x13000000-0x130001ff pref]: assigned
    Wait For Line On Uart           pci 0000:01:00.0: BAR 1 [mem 0x13000200-0x130003ff pref]: assigned
    Wait For Line On Uart           pci 0000:01:00.0: BAR 2 [mem 0x13000400-0x130005ff pref]: assigned
    Wait For Line On Uart           pci 0000:01:00.0: BAR 3 [mem 0x13000600-0x130007ff pref]: assigned
    Wait For Line On Uart           pci 0000:01:00.0: BAR 4 [mem 0x13000800-0x130009ff pref]: assigned
    Wait For Line On Uart           pci 0000:01:00.0: BAR 5 [mem 0x13000a00-0x13000bff pref]: assigned

    Wait For Line On Uart           pci 0000:00:00.0: PCI bridge to [bus 01]
    Wait For Line On Uart           pci 0000:00:00.0: \ \ bridge window [mem 0x13000000-0x130fffff pref]
    Wait For Line On Uart           pci_bus 0000:00: resource 4 [mem 0x13000000-0x131fffff]
    Wait For Line On Uart           pci_bus 0000:00: resource 5 [mem 0x14000000-0x141fffff]
    Wait For Line On Uart           pci_bus 0000:01: resource 2 [mem 0x13000000-0x130fffff pref]

    Provides                        bar-assigned

Should List Devices
    Requires                        bar-assigned

    Boot Linux And Login

    Write Line To Uart              lspci

    Wait For Line On Uart           00:00.0 PCI bridge: Synopsys, Inc. Device c0de                        timeout=15
    Wait For Line On Uart           01:00.0 Mass storage controller: Adnaco Technology Inc. Device cccc   timeout=15
    Wait For Prompt On Uart         ${PROMPT}

Should Check Internal BAR Map
    Requires                        bar-assigned

    ${bars}=  Execute Command       pcieHost PrintBars
    Should Be Equal As Strings      ${bars}     ${EXPECTED_BAR_LAYOUT}    collapse_spaces=${True}    strip_spaces=${True}

Should Write to Memory And Read Back
    Requires                        bar-assigned

    # Address that is mapped into BAR0 of the connected EP
    Execute Command                 sysbus WriteDoubleWord 0x13000004 0x21
    ${val}=  Execute Command        sysbus ReadDoubleWord 0x13000004
    Should Be Equal As Integers     ${val}    0x21
    # Check by directly reading through the BAR
    ${val}=  Execute Command        pcieHost.pcieMem1 MemoryReadDoubleWord 0 0x4
    Should Be Equal As Integers     ${val}    0x21
