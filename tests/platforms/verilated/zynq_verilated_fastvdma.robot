*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode
${PROMPT}                                zynq>
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fastvdma.resc
${UART}                                  sysbus.uart1
${FASTVDMA_DRIVER}                       /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${FASTVDMA_DEMO_DRIVER}                  /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma-demo.ko
${FASTVDMA_NATIVE_LINUX}                 ${URI}/libVfastvdma-Linux-x86_64-12904733885.so-s_2104432-8ec57bdee00c76a044024158525d4130af0afc1a
${FASTVDMA_NATIVE_WINDOWS}               ${URI}/libVfastvdma-Windows-x86_64-12904733885.dll-s_3265828-0e1691527cfb633cf5d8865f3445529708e73f8f
${FASTVDMA_NATIVE_MACOS}                 ${URI}/libVfastvdma-macOS-x86_64-12904733885.dylib-s_239144-ebd397eb4d74c08be26cec08c022e90b78f0e020

*** Keywords ***
Create Machine
    Execute Command                      \$dmaLinux?=${FASTVDMA_NATIVE_LINUX}
    Execute Command                      \$dmaWindows?=${FASTVDMA_NATIVE_WINDOWS}
    Execute Command                      \$dmaMacOS?=${FASTVDMA_NATIVE_MACOS}
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
    [Tags]                          skip_host_arm

    Create Machine
    Start Emulation
    Wait For Prompt On Uart              ${PROMPT}  timeout=300

    # Serialization on verilated platforms isn't working porperly at the moment. We use the old method instead
    Provides                             booted-linux  Reexecution

Should Load Drivers
    [Documentation]                      Loads fastvdma.ko and fastvdma-demo.ko and performs image transfer via FastVDMA.
    [Tags]                          skip_host_arm
    Requires                             booted-linux

# Suppress messages from kernel space; don't wait for echo because a kernel log might be printed in the middle of writing.
    Write Line To Uart                   echo 0 > /proc/sys/kernel/printk  waitForEcho=false

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
    [Tags]                          skip_host_arm
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
