*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
List Fomu in Linux
    Execute Command  using sysbus

    # Create an USB connector
    Execute Command  emulation CreateUSBConnector "usb_connector"

    # Create FOMU board
    Execute Command  mach create "fomu"
    Execute Command  machine LoadPlatformDescription @platforms/cpus/fomu.repl
    Execute Command  sysbus LoadELF @https://antmicro.com/projects/renode/fomu--foboot.elf-s_112080-c31fe1f32fba7894338f3cf4bfb82ec2a8265683
    Execute Command  connector Connect valenty usb_connector

    # Create Linux board
    Execute Command  mach clear
    Execute Command  set fdt @https://antmicro.com/projects/renode/hifive_unleashed_usb--devicetree_with_pse_usb.dtb-s_8894-5e4fb8fcdadcd8e35c841a430a83bf66df192c69
    Execute Command  set bin @https://antmicro.com/projects/renode/hifive_unleashed_usb--linux_kernel.elf-s_17313704-faa5d98a1388d52c9b9f9eb9202be6beb10021e9
    Execute Command  include @scripts/single-node/hifive_unleashed.resc
    Execute Command  machine LoadPlatformDescriptionFromString 'usb: USB.PSE_USB @ sysbus 0x30020000 { MainIRQ -> plic@5 }'

    Create Terminal Tester
    ...                         sysbus.uart0
    ...                         prompt=buildroot login:
    ...                         timeout=240
    ...                         machine=hifive-unleashed

    Start Emulation

    Wait For Prompt On Uart

    Set New Prompt For Uart       Password:
    Write Line To Uart            root
    Wait For Prompt On Uart

    Set New Prompt For Uart       \#
    Write Line To Uart            root             waitForEcho=False
    Wait For Prompt On Uart

    Execute Command               usb_connector RegisterInController usb
    Wait For Line On Uart         usb 1-1: new high-speed USB device number 2 using musb-hdrc
    Sleep                         5

    Write Line To Uart            cd /sys/bus/usb/devices
    Write Line To Uart            ls -l
    Wait For Line On Uart         1-1

    Write Line To Uart            cd 1-1

    Write Line To Uart            cat manufacturer
    Wait For Line On Uart         Foosn

    Write Line To Uart            cat product
    Wait For Line On Uart         Fomu PVT running DFU Bootloader v1.9-11-gc7ee25b

