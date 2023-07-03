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

${BIN}                                   @${CURDIR}/../../../fastvdma-binaries/vmlinux
${ROOTFS}                                @${CURDIR}/../../../fastvdma-binaries/rootfs.ext2
${DTB}                                   @${CURDIR}/../../../fastvdma-binaries/fastvdma-zedboard.dtb
${VIRTIO}                                @${CURDIR}/../../../fastvdma-binaries/empty.ext2
${FASTVDMA_AXILITE_NATIVE_LINUX}         ???
${FASTVDMA_AXILITE_NATIVE_WINDOWS}       ???
${FASTVDMA_AXILITE_NATIVE_MACOS}         ???

*** Keywords ***
Create Machine
    Execute Command                      using sysbus
    Execute Command                      mach create
    Execute Command                      machine LoadPlatformDescription @platforms/boards/zedboard.repl
    Execute Command                      machine LoadPlatformDescriptionFromString 'virtio: Storage.VirtIOBlockDevice @ sysbus 0x400d0000 { IRQ->gic@32 }'
    Execute Command                      machine LoadPlatformDescriptionFromString 'dma: Verilated.VerilatedPeripheral @ sysbus <0x43c20000, +0x100> { frequency: 100000; maxWidth: 4; limitBuffer: 100000; timeout: 10000; 0 -> gic@31; numberOfInterrupts: 1}'

    Execute Command                      sysbus Redirect 0xC0000000 0x0 0x10000000
    Execute Command                      dma SimulationFilePathLinux ${FASTVDMA_AXILITE_NATIVE_LINUX}
    Execute Command                      dma SimulationFilePathWindows ${FASTVDMA_AXILITE_NATIVE_WINDOWS}
    Execute Command                      dma SimulationFilePathMacOS ${FASTVDMA_AXILITE_NATIVE_MACOS}
    Execute Command                      cpu SetRegisterUnsafe 0 0x000
    Execute Command                      cpu SetRegisterUnsafe 1 0xD32 # board id
    Execute Command                      cpu SetRegisterUnsafe 2 0x100 # device tree address

    Execute Command                      sysbus LoadELF ${BIN}
    Execute Command                      sysbus LoadFdt ${DTB} 0x100 "console=ttyPS0,115200 root=/dev/ram0 rw earlyprintk initrd=0x1a000000,32M" false
    Execute Command                      sysbus ZeroRange 0x1a000000 0x800000
    Execute Command                      sysbus LoadBinary ${ROOTFS} 0x1a000000

    Execute Command                      virtio LoadImage ${VIRTIO} true

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


