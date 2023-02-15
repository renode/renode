*** Variables ***
${UART}                             sysbus.uart0
${PROMPT}                           \#${SPACE}
${I2C_ECHO_ADDRESS}                 0x10
${I2C_SENSOR_ADDRESS}               0x31
${FLASH_MOUNT}                      /mnt/spi_flash
${SAMPLE_FILENAME}                  data.bin
${MTD0_DEV}                         /dev/mtd0
${MTD0_BLOCK_DEV}                   /dev/mtdblock0
${CADENCE_XSPI_BIN}                 @https://dl.antmicro.com/projects/renode/zynq--cadence-xspi-vmlinux-s_14143972-449b7a25d689a4b6e2adc9ae4c3abbf375ccc70c
${CADENCE_XSPI_ROOTFS}              @https://dl.antmicro.com/projects/renode/zynq--cadence-xspi-rootfs.ext2-s_16777216-d1dabbf627ba4846963c97db8d27f5d4f454e72b
${CADENCE_XSPI_DTB}                 @https://dl.antmicro.com/projects/renode/zynq--cadence-xspi.dtb-s_11045-f5e1772bb1d19234ce6f0b8ec77c2f970660c7bb
${CADENCE_XSPI_PERIPHERAL}          SEPARATOR=\n
...                                 """
...                                 xspi: SPI.Cadence_xSPI @ {
...                                 sysbus 0xE0102000;
...                                 sysbus new Bus.BusMultiRegistration {
...                                 address: 0xe0104000; size: 0x100; region: "auxiliary"
...                                 };
...                                 sysbus new Bus.BusMultiRegistration {
...                                 address: 0xe0200000; size: 0x1000; region: "dma"
...                                 }
...                                 }
...                                 ${SPACE*4}IRQ -> gic@63
...
...                                 xspiFlash: SPI.Micron_MT25Q @ xspi 0 {
...                                 underlyingMemory: xspiFlashMemory;
...                                 extendedDeviceId: 0x44
...                                 }
...
...                                 xspiFlashMemory: Memory.MappedMemory {
...                                 size:  0x2000000
...                                 }
...                                 """

*** Keywords ***
Create Machine
    Execute Command                 include @scripts/single-node/zynq-7000.resc
    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c0 ${I2C_ECHO_ADDRESS}"
    Execute Command                 machine LoadPlatformDescriptionFromString "i2cSensor: Sensors.MAX30208 @ i2c0 ${I2C_SENSOR_ADDRESS}"
    Execute Command                 machine LoadPlatformDescriptionFromString "spiFlash0: SPI.Micron_MT25Q @ spi0 0 { underlyingMemory: spi0FlashMemory; extendedDeviceId: 0x44 }; spi0FlashMemory: Memory.MappedMemory { size: 0x2000000 }"
    Create Terminal Tester          ${UART}

Boot And Login
    Wait For Line On Uart           Booting Linux on physical CPU 0x0
    Wait For Prompt On Uart         buildroot login:  timeout=25
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}

Check Exit Code
    Write Line To Uart              echo $?
    Wait For Line On Uart           0
    Wait For Prompt On Uart         ${PROMPT}

Execute Linux Command
    [Arguments]                     ${command}  ${timeout}=5
    Write Line To Uart              ${command}
    Wait For Prompt On Uart         ${PROMPT}  timeout=${timeout}
    Check Exit Code

Get Linux Elapsed Seconds
    Write Line To Uart              date +%s
    ${date}=                        Wait For Line On Uart  ^([0-9]+)$  treatAsRegex=true
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code
    ${seconds}=                     Convert To Integer  ${date.line}
    [return]                        ${seconds}

Generate Random File
    [Arguments]                     ${filename}  ${size_kilobytes}
    Execute Linux Command           dd if=/dev/urandom of=./${filename} bs=1024 count=${size_kilobytes}

Should Mount Flash Memory And Write File
    [Arguments]                     ${mtd_dev}  ${mtd_block_dev}  ${mount_path}  ${random_filename}
    Execute Linux Command           flash_erase --jffs2 -N ${mtd_dev} 0 0
    Execute Linux Command           mkdir ${mount_path}
    Execute Linux Command           mount -t jffs2 ${mtd_block_dev} ${mount_path}
    Execute Linux Command           cp ./${random_filename} ${mount_path}

    Write Line To Uart              ls --color=never -1 ${mount_path}
    Wait For Line On Uart           ${random_filename}
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code
    Execute Linux Command           umount ${mount_path}

Should Mount Flash Memory And Compare Files
    [Arguments]                     ${mtd_block_dev}  ${mount_path}  ${random_filename}
    Execute Linux Command           mount -t jffs2 ${mtd_block_dev} ${mount_path}
    Execute Linux Command           cmp ${mount_path}/${random_filename} ./${random_filename}
    Execute Linux Command           umount ${mount_path}

Should Erase Flash Memory
    [Arguments]                     ${mtd_dev}  ${mtd_block_dev}  ${mount_path}
    Execute Linux Command           flash_erase --jffs2 -N ${mtd_dev} 0 0
    Execute Linux Command           mount -t jffs2 ${mtd_block_dev} ${mount_path}
    Write Line To Uart              ls -1 ${mount_path} | wc -l
    Wait For Line On Uart           0
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code
    Execute Linux Command           umount ${mount_path}

*** Test Cases ***
Should Boot And Login
    Create Machine
    Start Emulation

    Boot And Login
    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Provides                        logged-in

Should List Expected Devices
    Requires                        logged-in

    Write Line To Uart              ls --color=never -1 /dev/
    Wait For Line On Uart           i2c-0
    Wait For Line On Uart           mtd0
    Wait For Line On Uart           ttyPS0
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

Should Detect I2C Peripherals
    Requires                        logged-in

    Write Line To Uart              i2cdetect -yar 0
    Wait For Line On Uart           10: 10 --
    Wait For Line On Uart           30: -- 31 --
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    Write Line To Uart              i2cget -y 0 0x41
    Wait For Line On Uart           No such device
    Wait For Prompt On Uart         ${PROMPT}

Should Communicate With I2C Echo Peripheral
    Requires                        logged-in

    Write Line To Uart              i2ctransfer -ya 0 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart           0x01 0x23
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    # Very long commands are splited into many lines due to the terminal width (number of columns), which confused waitForEcho feature
    Write Line To Uart              i2ctransfer -ya 0 w20@${I2C_ECHO_ADDRESS} 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f 0x10 0x11 0x12 0x13 0x14 r21  waitForEcho=false
    Wait For Line On Uart           0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f 0x10 0x11 0x12 0x13 0x14 0x00
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    # Check target monitor feature
    Execute Linux Command           i2ctransfer -ya 0 w0@${I2C_ECHO_ADDRESS}

Should Communicate With MAX30208 Peripheral
    Requires                        logged-in

    # Write and read one register
    Execute Linux Command           i2cset -y 0 ${I2C_SENSOR_ADDRESS} 0x10 0xbe
    Write Line To Uart              i2cget -y 0 ${I2C_SENSOR_ADDRESS} 0x10
    Wait For Line On Uart           0xbe
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    # Read more bytes than I2C peripheral provides
    Write Line To Uart              i2ctransfer -ya 0 w0@${I2C_SENSOR_ADDRESS} r2
    Wait For Line On Uart           0x00 0x00
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    # Read weird number of bytes to check is FinishTransmission calling works properly
    Write Line To Uart              i2ctransfer -ya 0 w19@${I2C_SENSOR_ADDRESS} 0xff 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 r18  waitForEcho=false
    Wait For Line On Uart           0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

Should Access SPI Flash Memory
    Requires                        logged-in
    Generate Random File            ${SAMPLE_FILENAME}  5

    Should Mount Flash Memory And Write File  ${MTD0_DEV}  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}  ${SAMPLE_FILENAME}
    Should Mount Flash Memory And Compare Files  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}  ${SAMPLE_FILENAME}
    Should Erase Flash Memory       ${MTD0_DEV}  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}

Time Should Elapse
    Requires                        logged-in

    ${seconds_before}=              Get Linux Elapsed Seconds
    Execute Linux Command           sleep 2
    ${seconds}=                     Get Linux Elapsed Seconds
    Should Be True                  ${seconds_before} < ${seconds}

Should Access SPI Flash Memory Via Additional Cadence xSPI IP
    Execute Command                 $bin=${CADENCE_XSPI_BIN}
    Execute Command                 $rootfs=${CADENCE_XSPI_ROOTFS}
    Execute Command                 $dtb=${CADENCE_XSPI_DTB}

    Create Machine
    Execute Command                 machine LoadPlatformDescriptionFromString ${CADENCE_XSPI_PERIPHERAL}
    Start Emulation

    Boot And Login
    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              ls --color=never -1 /dev/
    Wait For Line On Uart           mtd0
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

    Generate Random File            ${SAMPLE_FILENAME}  5

    Should Mount Flash Memory And Write File  ${MTD0_DEV}  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}  ${SAMPLE_FILENAME}
    Should Mount Flash Memory And Compare Files  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}  ${SAMPLE_FILENAME}
    Should Erase Flash Memory       ${MTD0_DEV}  ${MTD0_BLOCK_DEV}  ${FLASH_MOUNT}
