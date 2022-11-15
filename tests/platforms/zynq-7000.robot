*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${UART}                         sysbus.uart0
${PROMPT}                       \#${SPACE}

*** Keywords ***
Create Machine
    Execute Command             include @scripts/single-node/zynq-7000.resc
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
