*** Keywords ***
Write To Uart And Wait
    [Arguments]            ${input}            ${expected_output}
    Write Line To Uart            ${input}
    Wait For Line On Uart         ${expected_output}

*** Test Cases ***
List Fomu in Linux
    Execute Command               using sysbus

    # Create an USB connector
    Execute Command               emulation CreateUSBConnector "usb_connector"

    # Create FOMU board
    Execute Command               mach create "fomu"
    Execute Command               machine LoadPlatformDescription @platforms/cpus/fomu.repl
    Execute Command               sysbus LoadELF @https://dl.antmicro.com/projects/renode/fomu--foboot.elf-s_112080-c31fe1f32fba7894338f3cf4bfb82ec2a8265683
    Execute Command               connector Connect valenty usb_connector

    # Create Linux board
    Execute Command               mach clear
    Execute Command               set fdt @https://dl.antmicro.com/projects/renode/hifive_unleashed_usb--devicetree_with_pse_usb.dtb-s_8894-5e4fb8fcdadcd8e35c841a430a83bf66df192c69
    Execute Command               set bin @https://dl.antmicro.com/projects/renode/hifive_unleashed_usb--bbl.elf-s_17285160-88e89cf2bb6dc92d176cfffcabb06b0d8b28c1cc
    Execute Command               include @scripts/single-node/hifive_unleashed.resc
    Execute Command               machine LoadPlatformDescriptionFromString 'usb: USB.MPFS_USB @ sysbus 0x30020000 { MainIRQ -> plic@0x20 }'

    Create Terminal Tester
    ...                           sysbus.uart0
    ...                           machine=hifive-unleashed

    Start Emulation

    Wait For Prompt On Uart       buildroot login:
    Write Line To Uart            root

    Wait For Prompt On Uart       Password:
    Write Line To Uart            root             waitForEcho=False

    Wait For Prompt On Uart       \#

    Execute Command               usb_connector RegisterInController usb
    Wait For Line On Uart         usb 1-1: new high-speed USB device number 2 using musb-hdrc
    Write Line To Uart            cd /sys/bus/usb/devices

    # it might take a while for the USB device to show up
    Wait Until Keyword Succeeds   10x    0
    ...  Write To Uart And Wait   ls -l
    ...                           1-1

    Write Line To Uart            cd 1-1

    Write Line To Uart            cat manufacturer
    Wait For Line On Uart         Foosn

    Write Line To Uart            cat product
    Wait For Line On Uart         Fomu PVT running DFU Bootloader v1.9-11-gc7ee25b

