*** Settings ***
Resource                            ../platforms/zynqmp.resource

*** Variables ***
${ZYNQ_GPIO_BASE}                  906
${ZYNQMP_GPIO_BASE}                334
${RUN_FOR_QUANTUM}                 0.0001
# First and last pin of each GPIO bank.
@{ZYNQ_TEST_PINS}                  0  31  32  53  54  85  86  117
@{ZYNQMP_TEST_PINS}                0  25  26  51  52  77  78  109  110  141  142  173

*** Keywords ***
Create Zynq-7000 Machine
    Execute Command                 $disabled_nodes=""
    Execute Command                 include @scripts/single-node/zedboard.resc
    ${tester}=                      Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true
    RETURN                          ${tester}

Create ZynqMP Machine
    # Don't bind GPIO pins as device pins, as this prevent them from being exported
    Execute Command                 $disabled_nodes="i2c@ff030000 leds gpio-keys"
    Execute Command                 include @scripts/single-node/zynqmp_linux.resc
    ${tester}=                      Create Terminal Tester  sysbus.uart1  defaultPauseEmulation=true
    RETURN                          ${tester}

Boot Zynq-7000 Linux And Login
    [Arguments]                     ${tester}
    Wait For Prompt On Uart         buildroot login:  timeout=25       testerId=${tester}
    Write Line To Uart              root                               testerId=${tester}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                    testerId=${tester}

Boot ZynqMP Linux And Login
    [Arguments]                     ${tester}
    Boot Linux And Login            testerId=${tester}

First And Last Input Of Each Bank Should Trigger Interrupt
    [Arguments]                     ${linux_gpio_base}  ${tester}  @{test_pins}
    Execute Linux Command           cd /sys/class/gpio  testerId=${tester}
    FOR  ${global_pin}  IN  @{test_pins}
        ${linux_pin}=               Evaluate  ${linux_gpio_base} + ${global_pin}

        Execute Linux Command       echo ${linux_pin} > export  testerId=${tester}
        Execute Linux Command       echo in > gpio${linux_pin}/direction  testerId=${tester}

        # edge=rising makes the Linux driver unmask and handle the interrupt.
        Execute Linux Command       echo rising > gpio${linux_pin}/edge  testerId=${tester}
        Execute Command             sysbus.gpio OnGPIO ${global_pin} True
        Execute Command             emulation RunFor "${RUN_FOR_QUANTUM}"
        Execute Command             sysbus.gpio OnGPIO ${global_pin} False
        Execute Command             emulation RunFor "${RUN_FOR_QUANTUM}"
        # Match e.g. "47: 0 1 0 0 zynq-gpio 31 Edge gpiolib". Any CPU can handle the IRQ,
        # so exactly one CPU counter must be 1 while all other CPU counters remain 0.
        Execute Linux Command       grep -Eq ': +(0 +)*1 +(0 +)*zynq-gpio +${global_pin} Edge +gpiolib' /proc/interrupts  testerId=${tester}

        Execute Linux Command       echo none>gpio${linux_pin}/edge;echo ${linux_pin}>unexport  testerId=${tester}
    END

*** Test Cases ***
Zynq-7000 Bank Boundary Inputs Should Respect Interrupt Mask
    [Tags]                          linux  gpio
    ${tester}=                      Create Zynq-7000 Machine
    Boot Zynq-7000 Linux And Login  ${tester}
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk  testerId=${tester}
    First And Last Input Of Each Bank Should Trigger Interrupt
    ...                             ${ZYNQ_GPIO_BASE}  ${tester}  @{ZYNQ_TEST_PINS}

ZynqMP Bank Boundary Inputs Should Respect Interrupt Mask
    [Tags]                          linux  gpio
    ${tester}=                      Create ZynqMP Machine
    Boot ZynqMP Linux And Login     ${tester}
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk  testerId=${tester}
    First And Last Input Of Each Bank Should Trigger Interrupt
    ...                             ${ZYNQMP_GPIO_BASE}  ${tester}  @{ZYNQMP_TEST_PINS}
