*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode/

${PROMPT}                                zynq>
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fastvdma.resc
${UART}                                  sysbus.uart1
${BIN}                                   ${URI}zynq-fastvdma_vmlinux-s_13611036-802d102e9341668636631447e99389f79043c18d
${DTB}                                   ${URI}zynq-fastvdma.dtb-s_12284-4f3a630a9bce9e0984151b95e9efa581ef7525bf
${ROOTFS}                                ${URI}zynq-fastvdma_rootfs.ext2-s_33554432-7a53506ed3e6cdaf247280ad7025ff1aa4cb98c5
${FASTVDMA_DRIVER}                       /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${FASTVDMA_DEMO_DRIVER}                  /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma-demo.ko

*** Keywords ***
Create Machine
    Execute Script	                 ${SCRIPT}
    Create Terminal Tester               ${UART}

Compare Parts Of Images
    [Arguments]                          ${img0}    ${img1}    ${count}    ${skip}

    Write Line To Uart                   dd if=${img0} of=test bs=128 count=${count} skip=${skip}
    Wait For Prompt On Uart              ${PROMPT}
    Write Line To Uart                   dd if=${img1} of=otest bs=128 count=${count} skip=${skip}
    Wait For Prompt On Uart              ${PROMPT}
    Write Line To Uart                   cmp test otest
# Check if exit status is 0 (the input files are the same)
    Write Line To Uart                   echo $?
    Wait For Line On Uart                0

*** Test Cases ***
Should Boot Linux
    [Documentation]                      Boots Linux on the Zynq 7000-based Zedboard platform in co-simulation with FastVDMA.

    Create Machine
    Start Emulation
    Wait For Prompt On Uart              ${PROMPT}  timeout=300

    Provides                             booted-linux

Should Load Drivers
    [Documentation]                      Loads fastvdma.ko and fastvdma-demo.ko and performs image transfer via FastVDMA.
    Requires                             booted-linux

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

    Provides                             output

Verify Image
    [Documentation]                      Verifies whether the image has been transferred correctly.
    Requires                             output

# Suppress messages from kernel space so it doesn't affect dd and cmp outputs
    Write Line To Uart                   echo 0 > /proc/sys/kernel/printk

# The output image (out.rgba) should consist of img1.rgba (256x256px) in the middle of img0.rgba (512x512px)
# Verify if that's correct by comparing corresponding bytes.

    Compare Parts Of Images              img0.rgba    out.rgba    2052    0

    FOR    ${i}    IN RANGE    255
        Compare Parts Of Images          img0.rgba    out.rgba    1    2052 + ${i}*4
        Compare Parts Of Images          img1.rgba    out.rgba    2    2053 + ${i}*4
        Compare Parts Of Images          img0.rgba    out.rgba    1    2055 + ${i}*4
    END

    Compare Parts Of Images              img0.rgba    out.rgba    2052    6140
