*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/miv-board.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Translate Code Address Should Not Fault
          Create Machine            shell-demo-miv.elf-s_803248-ea4ddb074325b2cc1aae56800d099c7cf56e592a

          Execute Command           using sysbus
          Execute Command           cpu ExecutionMode SingleStep

          Start Emulation

          Execute Command           cpu Step 5

  ${pa}=  Execute Command           cpu TranslateAddress 0x800100000 2 1    # nofault translation
          Should Contain            ${pa}       0xFFFFFFFFFFFFFFFF
  ${pa}=  Execute Command           cpu TranslateAddressNoFault 0x800100000    # same as above
          Should Contain            ${pa}       0xFFFFFFFFFFFFFFFF
          Provides                  unmapped_address

Translate Address Should Be Able To Map Address
          Requires                  unmapped_address

  ${pa}=  Execute Command           cpu TranslateAddress 0x800100000 2 0    # fault translation
          Should Contain            ${pa}       0x0000000000100000
  ${pa}=  Execute Command           cpu TranslateAddressNoFault 0x800100000
          Should Contain            ${pa}       0x0000000000100000

