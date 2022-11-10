*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${UART}                         sysbus.uart0
${PROMPT}                       \#${SPACE}
${FLASH0_PATH}                  /mnt/spi_flash0
${MTD0_DEV}                     /dev/mtd0
${MTD0_BLOCK_DEV}               /dev/mtdblock0
${SAMPLE_FILENAME}              data.bin

*** Keywords ***
Create Machine
    Execute Command             include @scripts/single-node/zynq-7000.resc
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
