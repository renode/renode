*** Variables ***
${URI}                                   @https://dl.antmicro.com/projects/renode/

${PROMPT}                                zynq>
${UART}                                  sysbus.uart1
${VM_BIN}                                ${URI}zynq-fastvdma_vmlinux-s_13611036-802d102e9341668636631447e99389f79043c18d
${DTB}                                   ${URI}zynq-fastvdma.dtb-s_12284-4f3a630a9bce9e0984151b95e9efa581ef7525bf
${ROOTFS}                                ${URI}zynq-fastvdma_rootfs.ext2-s_33554432-7a53506ed3e6cdaf247280ad7025ff1aa4cb98c5
${FASTVDMA_DRIVER}                       /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma.ko
${FASTVDMA_DEMO_DRIVER}                  /lib/modules/5.10.0-xilinx/kernel/drivers/dma/fastvdma/fastvdma-demo.ko
${FASTVDMA_NATIVE_LINUX}                 ${URI}zynq-fastvdma_libVfastvdma-Linux-x86_64-1246779523.so-s_2057616-93e755f7d67bc4d5ca33cce6c88bbe8ea8b3bd31
${FASTVDMA_NATIVE_WINDOWS}               ${URI}zynq-fastvdma_libVfastvdma-Windows-x86_64-1246779523.dll-s_14839852-62f85c68c37d34f17b10d39c5861780856d1698e
${FASTVDMA_NATIVE_MACOS}                 ${URI}libVfastvdma-macOS-x86_64-1246779523.dylib-s_230304-6c7a97c3b3adddf60bfb769e751403e85092c3b8

*** Keywords ***
Create Machine
    Execute Command                      mach create
    Execute Command                      machine LoadPlatformDescription @platforms/boards/zedboard.repl
    Execute Command                      machine LoadPlatformDescriptionFromString 'dma: Verilated.BaseDoubleWordVerilatedPeripheral @ sysbus <0x43c20000, +0x100> { frequency: 100000; limitBuffer: 100000; timeout: 10000; 0 -> gic@31; numberOfInterrupts: 1}'
    Execute Command                      sysbus Redirect 0xC0000000 0x0 0x10000000
    Execute Command                      using sysbus
    Execute Command                      showAnalyzer uart1
    Execute Command                      ttc0 Frequency 33333333
    Execute Command                      ttc1 Frequency 33333333
    Execute Command                      cpu SetRegisterUnsafe 0 0x000
    Execute Command                      cpu SetRegisterUnsafe 1 0xD32 # board id
    Execute Command                      cpu SetRegisterUnsafe 2 0x100 # device tree address
    Execute Command                      sysbus LoadELF ${VM_BIN}
    Execute Command                      sysbus LoadFdt ${DTB} 0x100 "console=ttyPS0,115200 root=/dev/ram0 rw earlyprintk initrd=0x1a000000,32M" false
    Execute Command                      sysbus ZeroRange 0x1a000000 0x800000
    Execute Command                      sysbus LoadBinary ${ROOTFS} 0x1a000000
    Execute Command                      dma SimulationFilePathLinux ${FASTVDMA_NATIVE_LINUX}
    Execute Command                      dma SimulationFilePathWindows ${FASTVDMA_NATIVE_WINDOWS}
    Execute Command                      dma SimulationFilePathMacOS ${FASTVDMA_NATIVE_MACOS}
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
