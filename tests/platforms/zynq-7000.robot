*** Variables ***
${UART}                         sysbus.uart0
${PROMPT}                       \#${SPACE}
${I2C_ECHO_ADDRESS}             0x10
${I2C_SENSOR_ADDRESS}           0x31
${FLASH0_PATH}                  /mnt/spi_flash0
${MTD0_DEV}                     /dev/mtd0
${MTD0_BLOCK_DEV}               /dev/mtdblock0
${SAMPLE_FILENAME}              data.bin

*** Keywords ***
Create Machine
    Execute Command             include @scripts/single-node/zynq-7000.resc
    Execute Command             machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c0 ${I2C_ECHO_ADDRESS}"
    Execute Command             machine LoadPlatformDescriptionFromString "i2cSensor: Sensors.MAX30208 @ i2c0 ${I2C_SENSOR_ADDRESS}"
    Execute Command             machine LoadPlatformDescriptionFromString "spiFlash: SPI.Micron_MT25Q @ spi0 0 { underlyingMemory: flashMemory }; flashMemory: Memory.MappedMemory { size: 0x800000 }"
    Create Terminal Tester      ${UART}

Boot And Login
    Create Machine
    Start Emulation

    Wait For Line On Uart       Booting Linux on physical CPU 0x0
    Wait For Prompt On Uart     buildroot login:    timeout=25
    Write Line To Uart          root
    Wait For Prompt On Uart     ${PROMPT}

Check Exit Code
    Write Line To Uart          echo $?
    Wait For Line On Uart       0
    Wait For Prompt On Uart     ${PROMPT}

Execute Linux Command
    [Arguments]                 ${command}    ${timeout}=5
    Write Line To Uart          ${command}
    Wait For Prompt On Uart     ${PROMPT}    timeout=${timeout}
    Check Exit Code

Get Linux Elapsed Seconds
    Write Line To Uart          date +%s
    ${date}=                    Wait For Line On Uart    ^([0-9]+)$    treatAsRegex=true
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code
    ${seconds}=                 Convert To Integer    ${date.line}
    [return]                    ${seconds}

*** Test Cases ***
Should Boot And Login
    Boot And Login
    # Suppress messages from the kernel space
    Execute Linux Command       echo 0 > /proc/sys/kernel/printk

    Provides                    logged-in

Should List Expected Devices
    Requires                    logged-in

    Write Line To Uart          ls --color=never -1 /dev/
    Wait For Line On Uart       i2c-0
    Wait For Line On Uart       mtd0
    Wait For Line On Uart       ttyPS0
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

Should Detect I2C Peripherals
    Requires                    logged-in

    Write Line To Uart          i2cdetect -yar 0
    Wait For Line On Uart       10: 10 --
    Wait For Line On Uart       30: -- 31 --
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    Write Line To Uart          i2cget -y 0 0x41
    Wait For Line On Uart       No such device
    Wait For Prompt On Uart     ${PROMPT}

Should Communicate With I2C Echo Peripheral
    Requires                    logged-in

    Write Line To Uart          i2ctransfer -ya 0 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart       0x01 0x23
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Very long commands are splited into many lines due to the terminal width (number of columns), which confused waitForEcho feature
    Write Line To Uart          i2ctransfer -ya 0 w20@${I2C_ECHO_ADDRESS} 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f 0x10 0x11 0x12 0x13 0x14 r21    waitForEcho=false
    Wait For Line On Uart       0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f 0x10 0x11 0x12 0x13 0x14 0x00
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Check target monitor feature
    Execute Linux Command       i2ctransfer -ya 0 w0@${I2C_ECHO_ADDRESS}

Should Communicate With MAX30208 Peripheral
    Requires                    logged-in

    # Write and read one register
    Execute Linux Command       i2cset -y 0 ${I2C_SENSOR_ADDRESS} 0x10 0xbe
    Write Line To Uart          i2cget -y 0 ${I2C_SENSOR_ADDRESS} 0x10
    Wait For Line On Uart       0xbe
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Read more bytes than I2C peripheral provides
    Write Line To Uart          i2ctransfer -ya 0 w0@${I2C_SENSOR_ADDRESS} r2
    Wait For Line On Uart       0x00 0x00
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Read weird number of bytes to check is FinishTransmission calling works properly
    Write Line To Uart          i2ctransfer -ya 0 w19@${I2C_SENSOR_ADDRESS} 0xee 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 r18    waitForEcho=false
    Wait For Line On Uart       0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x30
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Read many registers
    Write Line To Uart          i2ctransfer -ya 0 w1@${I2C_SENSOR_ADDRESS} 0x13 r16
    Wait For Line On Uart       0x00 0xc0 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x82 0x00 0x00
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

Should Access SPI Flash Memory
    Requires                    logged-in

    # Format flash to the JFFS2 file system and write a randomly generated file
    Execute Linux Command       flash_erase --jffs2 -N ${MTD0_DEV} 0 0
    Execute Linux Command       mkdir ${FLASH0_PATH}
    Execute Linux Command       mount -t jffs2 ${MTD0_BLOCK_DEV} ${FLASH0_PATH}
    Execute Linux Command       dd if=/dev/urandom of=./${SAMPLE_FILENAME} bs=1024 count=5
    Execute Linux Command       cp ./${SAMPLE_FILENAME} ${FLASH0_PATH}

    Write Line To Uart          ls --color=never -1 ${FLASH0_PATH}
    Wait For Line On Uart       ${SAMPLE_FILENAME}
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

    # Check is file correctly written
    Execute Linux Command       umount ${FLASH0_PATH}
    Execute Linux Command       mount -t jffs2 ${MTD0_BLOCK_DEV} ${FLASH0_PATH}
    Execute Linux Command       cmp ${FLASH0_PATH}/${SAMPLE_FILENAME} ./${SAMPLE_FILENAME}

    # Check flash erasing
    Execute Linux Command       umount ${FLASH0_PATH}
    Execute Linux Command       flash_erase --jffs2 -N ${MTD0_DEV} 0 0
    Execute Linux Command       mount -t jffs2 ${MTD0_BLOCK_DEV} ${FLASH0_PATH}
    Write Line To Uart          ls -1 ${FLASH0_PATH} | wc -l
    Wait For Line On Uart       0
    Wait For Prompt On Uart     ${PROMPT}
    Check Exit Code

Time Should Elapse
    Requires                    logged-in

    ${seconds_before}=          Get Linux Elapsed Seconds
    Execute Linux Command       sleep 2
    ${seconds}=                 Get Linux Elapsed Seconds
    Should Be True              ${seconds_before} < ${seconds}
