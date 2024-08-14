*** Variables ***
${UART}                       sysbus.uart0
${SWITCH}                     switch
${ETHERNET}                   sysbus.ethernet
${PROMPT}                     \#
${LOTS_OF_DATA}               yes hello world | head -n 1024
${URL}                        https://dl.antmicro.com/projects/renode

${EthernetDescription}  SEPARATOR=\n
...  """
...  ethernet: Network.SynopsysDWCEthernetQualityOfService @ {
...  ${SPACE*4}sysbus 0x40028000;
...  ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0x40028C00; size: 0x200; region: "mtl" };
...  ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0x40029000; size: 0x200; region: "dma" }
...  }
...  ${SPACE*4}systemClockFrequency: 433333333
...  ${SPACE*4}IRQ -> gic@22
...
...  phy0: Network.EthernetPhysicalLayer @ ethernet 0
...  ${SPACE*4}BasicStatus: 0x62A4
...  ${SPACE*4}Id1: 0x0141
...  ${SPACE*4}Id2: 0x0e40
...  ${SPACE*4}AutoNegotiationAdvertisement: 0x1e1
...  ${SPACE*4}AutoNegotiationLinkPartnerBasePageAbility: 0x1e1
...  ${SPACE*4}MasterSlaveControl: 0x300
...  ${SPACE*4}MasterSlaveStatus: 0x3000
...  """

*** Keywords ***
Create Machine
    [Arguments]               ${name}
    Execute Command           using sysbus
    Execute Command           emulation SetAdvanceImmediately true
    Execute Command           mach create "${name}"

    Execute Command           machine LoadPlatformDescription @platforms/cpus/zynq-7000.repl
    Execute Command           machine LoadPlatformDescriptionFromString ${EthernetDescription}

    Execute Command           set bin @${URL}/zynq--synopsys-dwc-qos-ethernet-vmlinux-s_14385668-e7b88e1decdd7da50b5717f4117ec5ccc9be812f
    Execute Command           set dtb @${URL}/zynq--synopsys-dwc-qos-ethernet-7000.dtb-s_12704-94873f422dba94e96f5e91862e660d508ade8ec1
    Execute Command           set rootfs @${URL}/zynq--cadence-xspi-rootfs.ext2-s_16777216-65f5f502eb4a970cb0e24b5382a524a99ed9e360

    Execute Command           sysbus Redirect 0xC0000000 0x0 0x10000000

# Set timer frequency
    Execute Command           ttc0 Frequency 33333333
    Execute Command           ttc1 Frequency 33333333

# Set registers
    Execute Command           cpu SetRegister 0 0x000
    Execute Command           cpu SetRegister 1 0xD32 # processor variant (cortex-a9)
    Execute Command           cpu SetRegister 2 0x100 # device tree address

    Execute Command           sysbus LoadELF $bin
    Execute Command           sysbus LoadFdt $dtb 0x100 "console=ttyPS0,115200 ramdisk_size=65536 root=/dev/ram0 rw initrd=0x1a000000,64M" false
    Execute Command           sysbus ZeroRange 0x1a000000 0x800000
    Execute Command           sysbus LoadBinary $rootfs 0x1a000000

    Execute Command           showAnalyzer ${UART}

    Execute Command           connector Connect ${ETHERNET} ${SWITCH}

*** Test Cases ***
Should Ping
    Execute Command           emulation CreateSwitch "${SWITCH}"

    Create Machine            machine
    Create Terminal Tester    ${UART}
    Create Network Interface Tester  ${ETHERNET}

    Start Emulation

    Wait For Prompt On Uart   buildroot login:                                  timeout=60
    Write Line To Uart        root

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:06
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 192.168.0.1 netmask 255.255.255.0
    Wait For Line On Uart     Link is Up
    Write Line To Uart
    Wait For Prompt On Uart   ${PROMPT}

    # This is a single machine setup so we need to add manually the ARP entry
    Write Line To Uart        arp -s 192.168.0.2 02:01:03:05:04:07
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ping -c 2 -p 42 -s 11 192.168.0.2
    Wait For Line On Uart     --- 192.168.0.2 ping statistics ---               timeout=20

    Wait For Outgoing Packet With Bytes At Index  020103050407020103050406080045000027____4000__01____c0a80001c0a800020842________0000________42424242424242  0  10  10
    Wait For Outgoing Packet With Bytes At Index  020103050407020103050406080045000027____4000__01____c0a80001c0a800020842________0001________42424242424242  0  10  10
    Wait For Prompt On Uart   ${PROMPT}

Should Send UDP
    Execute Command           emulation CreateSwitch "${SWITCH}"

    Create Machine            machine
    Create Terminal Tester    ${UART}
    Create Network Interface Tester  ${ETHERNET}

    Start Emulation

    Wait For Prompt On Uart   buildroot login:                                  timeout=60
    Write Line To Uart        root

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:06
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 192.168.0.1 netmask 255.255.255.0
    Wait For Line On Uart     Link is Up
    Write Line To Uart
    Wait For Prompt On Uart   ${PROMPT}

    # This is a single machine setup so we need to add manually the ARP entry
    Write Line To Uart        arp -s 192.168.0.2 02:01:03:05:04:07
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        yes "Hello World! " | head -n 128 | nc -uc 192.168.0.2 6069
    Wait For Outgoing Packet With Bytes At Index  02010305040702010305040608004500041c__________11____c0a80001c0a80002____17b50408____48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a4865  0  10  10
    Wait For Outgoing Packet With Bytes At Index  02010305040702010305040608004500031c__________11____c0a80001c0a80002____17b50308____6c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a48656c6c6f20576f726c6421200a  0  10  10
    Wait For Prompt On Uart   ${PROMPT}

Should Transfer File Via TFTP
    Execute Command           emulation CreateSwitch "${SWITCH}"

    Execute Command           emulation CreateNetworkServer "server" "192.168.0.100"
    Execute Command           connector Connect server ${SWITCH}
    Execute Command           server StartTFTP 6069
    ${test_file}=             Allocate Temporary File
    Create File               ${test_file}  hello world\n
    Execute Command           server.tftp ServeFile @${test_file} "hw"

    Create Machine            machine
    Create Terminal Tester    ${UART}
    Create Network Interface Tester  ${ETHERNET}

    Start Emulation

    Wait For Prompt On Uart   buildroot login:                                  timeout=60
    Write Line To Uart        root

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:06
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ifconfig eth0 192.168.0.1 netmask 255.255.255.0
    Wait For Line On Uart     Link is Up
    Write Line To Uart
    Wait For Prompt On Uart   ${PROMPT}

    Write Line To Uart        tftp -gr hw 192.168.0.100 6069
    Wait For Prompt On Uart   ${PROMPT}

    # Wait for Read Request
    Wait For Outgoing Packet With Bytes At Index  0000deadbeef02010305040608004500002f__________11____c0a80001c0a80064____17b5001b____00016877006f63746574007473697a65003000________  0  10  10

    # Compare contents, but ignore whitespaces due to OS dependent handling of new line, CR LF vs LF
    Write Line To Uart        diff -w hw <(echo hello world) > /dev/null && echo success || echo failure
    Wait For Line On Uart     success

Should Send Lots Of Data Via TCP Twice
    Execute Command           emulation CreateSwitch "${SWITCH}"

    Create Machine            machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0

    Create Machine            machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1

    Start Emulation

    Wait For Prompt On Uart   buildroot login:                                  testerId=${tester-0}  timeout=60
    Wait For Prompt On Uart   buildroot login:                                  testerId=${tester-1}  timeout=60
    Write Line To Uart        root                                              testerId=${tester-0}
    Write Line To Uart        root                                              testerId=${tester-1}

    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-0}
    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-1}
    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:06          testerId=${tester-0}
    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:07          testerId=${tester-1}
    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-0}
    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-1}
    Write Line To Uart        ifconfig eth0 192.168.0.1 netmask 255.255.255.0   testerId=${tester-0}
    Write Line To Uart        ifconfig eth0 192.168.0.2 netmask 255.255.255.0   testerId=${tester-1}
    Wait For Line On Uart     Link is Up                                        testerId=${tester-0}
    Wait For Line On Uart     Link is Up                                        testerId=${tester-1}
    Write Line To Uart                                                          testerId=${tester-0}
    Write Line To Uart                                                          testerId=${tester-1}
    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-0}
    Wait For Prompt On Uart   ${PROMPT}                                         testerId=${tester-1}

    Write Line To Uart        diff <(${LOTS_OF_DATA}) <(nc -l -p 7769) > \\     testerId=${tester-1}
    Write Line To Uart        /dev/null && echo success || echo failure         testerId=${tester-1}

    Write Line To Uart        ${LOTS_OF_DATA} | nc -c 192.168.0.2 7769          testerId=${tester-0}

    Wait For Line On Uart     success                                           testerId=${tester-1}  timeout=10

    Write Line To Uart        diff <(${LOTS_OF_DATA}) <(nc -l -p 7769) > \\     testerId=${tester-1}
    Write Line To Uart        /dev/null && echo success || echo failure         testerId=${tester-1}

    Write Line To Uart        ${LOTS_OF_DATA} | nc -c 192.168.0.2 7769          testerId=${tester-0}

    Wait For Line On Uart     success                                           testerId=${tester-1}  timeout=10
