*** Settings ***
Test Timeout                    2 minutes


*** Variables ***
${URI}                          @https://dl.antmicro.com/projects/renode

${HIFIVE1}=     SEPARATOR=
...  """                                        ${\n}
...  using "platforms/cpus/sifive-fe310.repl"   ${\n}
...                                             ${\n}
...  clint:                                     ${\n}
...  ${SPACE*4}frequency: 16000000              ${\n}
...  """


*** Keywords ***
Create Machine
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescriptionFromString ${HIFIVE1}
    Execute Command             sysbus LoadELF ${URI}/hifive1_revb--zephyr-tests-memprotect-protection.elf-s_456552-a281d83d018c9245a02c87a7be0c4f1d7ec04942
    Execute Command             sysbus Tag <0x10008000 4> "PRCI_HFROSCCFG" 0xFFFFFFFF
    Execute Command             sysbus Tag <0x10008008 4> "PRCI_PLLCFG" 0xFFFFFFFF
    Execute Command             cpu PerformanceInMips 320

    Create Terminal Tester      sysbus.uart0


*** Test Cases ***
Should Pass Zephyr "mem_protect/protection" Test suite on HiFive1_RevB
    Create Machine
    Execute Command             start
    Wait For Line On Uart       PROJECT EXECUTION SUCCESSFUL
