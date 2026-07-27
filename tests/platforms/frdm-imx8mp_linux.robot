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

    Provides                      Booted QNX


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

    # Round-trip random data through /dev/mtd0 - get random file, write it to mtd0, read it back, contents must match.
    FOR    ${size}    IN    810  811  812  813  814  815  816  817
        Write Line To Uart         head -c ${size} /dev/urandom > /test_file
        Wait For Prompt On Uart    \#${SPACE}
        Write Line To Uart         dd if=/test_file of=/dev/mtd0
        Wait For Prompt On Uart    \#${SPACE}
        Write Line To Uart         dd if=/dev/mtd0 of=/rb bs=${size} count=1
        Wait For Prompt On Uart    \#${SPACE}
        Write Line To Uart         cmp -s /test_file /rb && echo NOR_ROUNDTRIP_OK || echo "size=${size} NOR_ROUNDTRIP_FAIL"  waitForEcho=false
        Wait For Line On Uart      NOR_ROUNDTRIP_OK
        Wait For Prompt On Uart    \#${SPACE}
    END


Should Read Data From eMMC boot0 Hardware Partition
    [Documentation]
...         /dev/mmcblk2boot0 = eMMC's raw boot0 hardware partition, no filesystem:
...         U-Boot stores its environment there at 0x3F0000 as NUL-separated key=value
...         pairs, so reading it back proves the eMMC survived boot and `saveenv` worked
    Requires                      Booted QNX

    Write Line To Uart            dd if=/dev/mmcblk2boot0 bs=1 skip=$((0x3F0000)) count=$((0x1000)) 2>/dev/null | tr '\\0' '\\n'  waitForEcho=false
    # content= names the keyword arg; `board=imx8mp_frdm` is the keyword that we match on
    Wait For Line On Uart         content=board=imx8mp_frdm

