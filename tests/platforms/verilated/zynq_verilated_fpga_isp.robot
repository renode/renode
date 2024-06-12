*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode
${PROMPT}                                zynq>
${UART}                                  sysbus.uart0
${SCRIPT}                                ${CURDIR}/../../../scripts/single-node/zynq_verilated_fpga_isp.resc
${PLATFORM}                              @platforms/boards/mars_zx3.repl
${FPGA_ISP_NATIVE_LINUX}                 ${URI}/libVfpga_isp-Linux-x86_64-10267006380.so-s_2489640-93c05c5b2132714b5087fbfb2f4b86f972630786
${FPGA_ISP_NATIVE_WINDOWS}               ${URI}/libVfpga_isp-Windows-x86_64-10267006380.dll-s_3665464-1791f6faaa9ec5bea10d09e606c5ce5e3faa0b93
${FPGA_ISP_NATIVE_MACOS}                 ${URI}/libVfpga_isp-macOS-x86_64-10267006380.dylib-s_466960-03111da47b210dcec4e144057b1332f9e63e69e1
${BIN_VM}                                ${URI}/zynq-verilated-fpga-isp--vmlinux-s_13735336-6a3e10bd5b6d301cc8846490cad6de9ec541e067
${ROOTFS}                                ${URI}/zynq-verilated-fpga-isp--rootfs.ext2-s_33554432-cc9664564461b5be36a4d1841e50a760dc7f5ad1
${DTB}                                   ${URI}/zynq-verilated-fpga-isp--video-board.dtb-s_13451-bdb696327471e2247f811b03f37be84df994379a
${VIRTIO}                                ${URI}/empty-ext4-filesystem.img-s_33554432-1eb65a808612389cc35a69b81178fbad5708a863
${FASTVDMA_DRIVER}                       /lib/modules/5.15.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${DEMOSAICER_DRIVER}                     /lib/modules/5.15.0-xilinx/kernel/drivers/media/platform/demosaicer/zynq_demosaicer.ko

*** Keywords ***
Create Machine
    Execute Command                      \$ispLinux?=${FPGA_ISP_NATIVE_LINUX}
    Execute Command                      \$ispWindows?=${FPGA_ISP_NATIVE_WINDOWS}
    Execute Command                      \$ispMacOS?=${FPGA_ISP_NATIVE_MACOS}
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
