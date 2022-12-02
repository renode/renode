*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode/

${PROMPT}                                zynq>
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fastvdma_with_axilite.resc
${UART}                                  sysbus.uart1
${DEMO_SCRIPT}                           run-demo.sh

*** Keywords ***
Create Machine
    Execute Script                       ${SCRIPT}
    Create Terminal Tester               ${UART}

*** Test Cases ***
Should Boot Linux
    [Documentation]                      Boots Linux on the Zynq 7000-based Zedboard platform in co-simulation with FastVDMA.

    Create Machine
    Start Emulation
    Wait For Prompt On Uart              ${PROMPT}  timeout=300

    # Serialization on verilated platforms isn't working porperly at the moment. We use the old method instead
    Provides                             booted-linux  Reexecution

Should Run Demo
    [Documentation]                      Loads fastvdma.ko and fastvdma-demo.ko and performs image transfer via FastVDMA.
    Requires                             booted-linux

# Suppress messages from kernel space
    Write Line To Uart                   echo 0 > /proc/sys/kernel/printk

    Write To Uart                        ./${DEMO_SCRIPT} ${\n}
    Wait For Prompt On Uart              ${PROMPT}  timeout=3000

    # Serialization on verilated platforms isn't working porperly at the moment. We use the old method instead
    Provides                             output  Reexecution

Verify Image
    [Documentation]                      Verifies whether the image has been transferred correctly.
    Requires                             output

# The output image (out.rgba) should consist be identical to the input image.
    Write Line To Uart                   cmp out.rgba img.rgba
    Wait For Prompt On Uart              ${PROMPT}

# Check if exit status is 0 (given files do not differ)
    Write Line To Uart                   echo $?
    Wait For Line On Uart                0
    Wait For Prompt On Uart              ${PROMPT}


