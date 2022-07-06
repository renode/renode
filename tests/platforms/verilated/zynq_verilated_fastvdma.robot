*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode/

${PROMPT}                                zynq>
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fastvdma.resc
${UART}                                  sysbus.uart1
${FASTVDMA_DRIVER}                       /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${FASTVDMA_DEMO_DRIVER}                  /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma-demo.ko

*** Keywords ***
Create Machine
    Execute Script                       ${SCRIPT}
    Create Terminal Tester               ${UART}

Compare Parts Of Images
    [Arguments]                          ${img0}    ${img1}    ${count}    ${skip0}    ${skip1}

    Write Line To Uart                   dd if=${img0} of=test.rgba bs=128 count=${count} skip=${skip0}
    Wait For Prompt On Uart              ${PROMPT}
    Write Line To Uart                   dd if=${img1} of=otest.rgba bs=128 count=${count} skip=${skip1}
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   cmp test.rgba otest.rgba
    Wait For Prompt On Uart              ${PROMPT}

# Check if exit status is 0 (the input files are the same)
    Write Line To Uart                   echo $?
    Wait For Line On Uart                0
    Wait For Prompt On Uart              ${PROMPT}

*** Test Cases ***
Should Boot Linux
    [Documentation]                      Boots Linux on the Zynq 7000-based Zedboard platform in co-simulation with FastVDMA.

    Create Machine
    Start Emulation
    Wait For Prompt On Uart              ${PROMPT}  timeout=300

    # Serialization on verilated platforms isn't working porperly at the moment. We use the old method instead
    Provides                             booted-linux  Reexecution

Should Load Drivers
    [Documentation]                      Loads fastvdma.ko and fastvdma-demo.ko and performs image transfer via FastVDMA.
    Requires                             booted-linux

# Suppress messages from kernel space
    Write Line To Uart                   echo 0 > /proc/sys/kernel/printk

# Write Line To Uart for some reason breaks this line into two.
    Write To Uart                        insmod ${FASTVDMA_DRIVER} ${\n}
    Wait For Prompt On Uart              ${PROMPT}

    Write To Uart                        insmod ${FASTVDMA_DEMO_DRIVER} ${\n}
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   lsmod
    Wait For Line On Uart                Module
    Wait For Line On Uart                fastvdma_demo
    Wait For Line On Uart                fastvdma

    Write Line To Uart                   ./demo
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   chmod +rw out.rgba
    Wait For Prompt On Uart              ${PROMPT}

    # Serialization on verilated platforms isn't working porperly at the moment. We use the old method instead
    Provides                             output  Reexecution

Verify Image
    [Documentation]                      Verifies whether the image has been transferred correctly.
# On CI we observed deadlocks when targeting dotnet, skip this test until it's resolved
    [Tags]                               skip_dotnet
    Requires                             output

# The output image (out.rgba) should consist of img1.rgba (256x256px) in the middle of img0.rgba (512x512px)
# Verify if that's correct by comparing corresponding bytes.

    Compare Parts Of Images              img0.rgba    out.rgba    2048    0    0

    FOR    ${i}    IN RANGE    255
        Compare Parts Of Images          img0.rgba    out.rgba    4    ${2048 + ${i} * 16}    ${2048 + ${i} * 16}
        Compare Parts Of Images          img1.rgba    out.rgba    8    ${${i} * 8}    ${2052 + ${i} * 16}
        Compare Parts Of Images          img0.rgba    out.rgba    4    ${2060 + ${i} * 16}    ${2060 + ${i} * 16}
    END

    Compare Parts Of Images              img0.rgba    out.rgba    2052    6140    6140
