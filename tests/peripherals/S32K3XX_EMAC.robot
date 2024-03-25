*** Variables ***
${SWITCH}                           switch
${ETHERNET}                         sysbus.emac0
${UART}                             sysbus.lpuart2
${TFTP_BIN}                         https://dl.antmicro.com/projects/renode/mr_canhubk3--zephyr-samples_tftp_client.elf-s_4221436-4506026fa27d356a09719cc60c1750449b11cc80
${EMAC_PERIPHERAL}                  SEPARATOR=${\n}
...                                 """
...                                 emac0: Network.S32K3XX_EMAC @ sysbus 0x40480000
...                                 ${SPACE*4}systemClockFrequency: 50000000
...                                 ${SPACE*4}IRQ->nvic0@105
...                                 ${SPACE*4}Channel0TX->nvic0@106
...                                 ${SPACE*4}Channel0RX->nvic0@107
...                                 """

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/nxp-s32k388.repl

    # The test binary is built for s32k344 as Zephyr currently doesn't support s32k388. Due to that mismatch we
    # need to change the ethernet controller to match what software expects.
    Execute Command                 sysbus Unregister sysbus.gmac0
    Execute Command                 machine LoadPlatformDescriptionFromString ${EMAC_PERIPHERAL}

    ${reset_macro}=                 Catenate  SEPARATOR=${\n}
    ...                             """
    ...                             sysbus LoadELF @${elf}
    ...                             sysbus.cpu0 VectorTableOffset `sysbus GetSymbolAddress "_vector_table"`
    ...                             """
    Execute Command                 macro reset${\n}${reset_macro}
    Execute Command                 runMacro $reset

*** Test Cases ***
Should Transfer Files via TFTP
    ${test_file}=                   Allocate Temporary File
    Create File                     ${test_file}  hello!\n

    Create Machine                  ${TFTP_BIN}

    Execute Command                 emulation CreateSwitch "${SWITCH}"
    Execute Command                 emulation CreateNetworkServer "server" "192.0.2.2"
    Execute Command                 connector Connect server ${SWITCH}
    Execute Command                 server StartTFTP 69
    Execute Command                 server.tftp ServeFile @${test_file} "file1.bin"
    Execute Command                 server.tftp LogReceivedFiles true
    Execute Command                 connector Connect ${ETHERNET} ${SWITCH}

    Create Terminal Tester          ${UART}
    Create Log Tester               1

    Wait For Line On UART           Run TFTP client
    Wait For Line On UART           Received data:
    Wait For Line On UART           68 65 6c 6c 6f 21 0a\\s+|hello!\.  treatAsRegex=true
    Wait For Line On UART           TFTP client get done
    Wait For Line On UART           TFTP client put done
    Wait For Log Entry              Received file 'newfile.bin': Lorem ipsum dolor sit amet, consectetur adipiscing elit
