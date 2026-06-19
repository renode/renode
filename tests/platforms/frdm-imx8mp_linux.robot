*** Test Cases ***
Should Boot Linux
    [Documentation]               Boots Linux to a shell

    [Timeout]                     NONE
    Execute Command               include @scripts/single-node/nxp-imx8mplus_linux.resc
    Create Terminal Tester        sysbus.uart2  timeout=120

    Wait For Line On Uart         ==== Hello World! Linux i.MX 8M Plus ====
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            uname -a
    Wait For Line On Uart         Linux
    Wait For Prompt On Uart       \#${SPACE}

Should Detect And Round-Trip SPI NOR On eCSPI2
    [Documentation]
...         eCSPI2 = Linux "spi1", chip-selects on GPIO5:
...         CS1 gpio5 4 -> ecspi2@1 -> jedec,spi-nor 64 MiB -> /dev/mtd0 (spi1.1)

    [Timeout]                     NONE
    Execute Command               include @scripts/single-node/nxp-imx8mplus_linux.resc
    Execute Command               machine LoadPlatformDescriptionFromString "gpio5: { 4 -> ecspi2@1 }"
    Execute Command               machine LoadPlatformDescriptionFromString "spiNorBackingMemory: Memory.MappedMemory @ sysbus 0x04000000 { size: 0x04000000 }"
    Execute Command               machine LoadPlatformDescriptionFromString "spiNor: SPI.GenericSpiFlash @ ecspi2 1 { underlyingMemory: spiNorBackingMemory; manufacturerId: 0x20; memoryType: 0xbb; extendedDeviceId: 0x44; capacityCode: 0x20 }"

    Create Terminal Tester        sysbus.uart2  timeout=120

    Wait For Line On Uart         ==== Hello World! Linux i.MX 8M Plus ====
    Wait For Prompt On Uart       \#${SPACE}

    # eCSPI2 CS1 (gpio5 4) spi-nor at `spi1.1`
    Write Line To Uart            cat /proc/mtd
    Wait For Line On Uart         mtd0: 04000000 00001000 "spi1.1"
    Wait For Prompt On Uart       \#${SPACE}

    # Round-trip a file through /dev/mtd0 - write it, read it back, md5sums must match.
    Write Line To Uart            dmesg > /test_file
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            dd if=/test_file of=/dev/mtd0
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            dd if=/dev/mtd0 of=/readback bs=$(stat -c%s /test_file) count=1
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            md5sum < /test_file > /sum_test
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            md5sum < /readback > /sum_read
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            cmp -s /sum_test /sum_read && echo NOR_ROUNDTRIP_OK || echo NOR_ROUNDTRIP_FAIL
    Wait For Line On Uart         NOR_ROUNDTRIP_OK
