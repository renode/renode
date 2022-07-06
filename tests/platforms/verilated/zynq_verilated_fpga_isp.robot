*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode
${PROMPT}                                zynq>
${UART}                                  sysbus.uart0
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fpga_isp.resc
${FASTVDMA_DRIVER}                       /lib/modules/5.15.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${DEMOSAICER_DRIVER}                     /lib/modules/5.15.0-xilinx/kernel/drivers/media/platform/demosaicer/zynq_demosaicer.ko

*** Keywords ***
Create Machine
    Execute Script                       ${SCRIPT}
    Create Terminal Tester               ${UART}

Should Load Drivers
    [Documentation]                      Loads fastvdma.ko and zynq_demosaicer.ko drivers.

    # Suppress messages from kernel space so it doesn't affect dd and cmp outputs
    Write Line To Uart                   echo 0 > /proc/sys/kernel/printk

    # It seems like the simulated shell splits long lines what messes with `waitForEcho` in the terminal tester
    Write Line To Uart                   insmod ${FASTVDMA_DRIVER}  waitForEcho=false
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   insmod ${DEMOSAICER_DRIVER}  waitForEcho=false
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   lsmod
    Wait For Line On Uart                Module
    Wait For Line On Uart                zynq_demosaicer
    Wait For Line On Uart                fastvdma

Should Run v4l2-ctl and Debayer Images
    [Documentation]                      Sets image to FPGA ISP input, runs v4l2-ctl and transfers said image through FPGA ISP which debayers it and saves the output.

    Write Line To Uart                   ./write_image
    Wait For Prompt On Uart              ${PROMPT}

    Write Line To Uart                   v4l2-ctl -d0 --set-fmt-video=width=600,height=398,pixelformat=RGB4 --stream-mmap --stream-count=1 --stream-to=out0.rgb  waitForEcho=false
    Wait For Line On Uart                <  timeout=300
    Wait For Prompt On Uart              ${PROMPT}  timeout=100

    Write Line To Uart                   v4l2-ctl -d0 --set-fmt-video=width=600,height=398,pixelformat=RGB4 --stream-mmap --stream-count=1 --stream-to=out1.rgb  waitForEcho=false
    Wait For Line On Uart                <  timeout=300
    Wait For Prompt On Uart              ${PROMPT}  timeout=100

Verify Images
    [Documentation]                      Verifies whether the image has been transferred correctly.

    # Verify if the images were debayered correctly
    Write Line To Uart                   cmp -s out0.rgb out1.rgb && echo "CMP success" || echo "CMP failure"  waitForEcho=false
    Wait For Line On Uart                CMP success

*** Test Cases ***

FPGA ISP Debayer On Native Communication
    [Documentation]                      Test FPGA ISP debayering.

    Create Machine
    Start Emulation
    Wait For Prompt On Uart              ${PROMPT}  timeout=300
    Should Load Drivers
    Should Run v4l2-ctl and Debayer Images
    Verify Images
