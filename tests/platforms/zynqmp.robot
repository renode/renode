*** Variables ***
${UART}                             sysbus.uart1
${PROMPT}                           \#${SPACE}
${UBOOT_PROMPT}                     ZynqMP>
${I2C_ECHO_ADDRESS}                 0x10

*** Keywords ***
Create Machine
    Execute Command                 include @scripts/single-node/zynqmp_linux.resc
    Create Terminal Tester          ${UART}

Boot U-Boot And Launch Linux
    Wait For Line On Uart           U-Boot 2023.01
    Wait For Line On Uart           Starting kernel ...

Boot Linux And Login
    Wait For Prompt On Uart         buildroot login:  timeout=50
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

*** Test Cases ***
Should Boot And Login
    Create Machine
    Start Emulation

    Boot U-Boot And Launch Linux
    Boot Linux And Login

Should Detect I2C Peripherals
    Create Machine
    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"
    Start Emulation

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              i2cdetect -yar 1
    Wait For Line On Uart           10: 10 --
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

Should Communicate With I2C Echo Peripheral
    Create Machine
    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"
    Start Emulation

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              i2ctransfer -ya 1 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart           0x01 0x23
    Wait For Prompt On Uart         ${PROMPT}
    Check Exit Code

Should Display Output on GPIO
    Create Machine
    Execute Command                 machine LoadPlatformDescriptionFromString "gpio: { 7 -> heartbeat@0 }; heartbeat: Miscellaneous.LED @ gpio 7"
    Create LED Tester               sysbus.gpio.heartbeat  defaultTimeout=2
    Start Emulation

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              echo none > /sys/class/leds/heartbeat/trigger
    Write Line To Uart              echo 1 > /sys/class/leds/heartbeat/brightness
    Assert LED State                true
    Write Line To Uart              echo 0 > /sys/class/leds/heartbeat/brightness
    Assert LED State                false
