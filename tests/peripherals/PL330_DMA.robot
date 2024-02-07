*** Variables ***
${PROJECT_URL}                      https://dl.antmicro.com/projects/renode

${PLATFORM}                         platforms/cpus/cortex-a53-gicv3.repl
${ZEPHYR-BIN}                       ${PROJECT_URL}/cortex-a53--zephyr-pl330-dma_loop_tests.elf-s_70008-bdfc1e055c0dc33dbc846d085bab60e1cdd33352

${LINUX-SCRIPT}                     scripts/single-node/zedboard.resc
${LINUX-BIN}                        ${PROJECT_URL}/zynq--pl330-dmatest-vmlinux-s_15041432-5c3eb414a72bb23cc7bc425163945a5a8f9f10b5
# This DT is modified for peripheral transfer tests - it inserts STM USART that is not normally available for this platform
# and connects it to the DMA Controller, using `dmas` property of the USART's node, to test peripheral to memory DMA transfers
${LINUX-DTB}                        ${PROJECT_URL}/zynq--pl330-dmatest-devicetree.dtb-s_12003-4d13125ea98eaafb4df8854dc43b2dbb31a5bac2
${LINUX-ROOTFS}                     ${PROJECT_URL}/zynq--pl330-dmatest-vmlinux-rootfs.ext2-s_16777216-335b589cf4048764907362ec668c29db88644ffc
${PROMPT}                           \#${SPACE}

${UART}                             sysbus.uart0

*** Keywords ***
Create Zephyr Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "dma_program_memory: Memory.MappedMemory @ sysbus 0x93B0000 { size: 0x10000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "dma: DMA.PL330_DMA @ sysbus 0x9300000"
    Execute Command                 sysbus LoadELF @${ZEPHYR-BIN}

    Create Terminal Tester          ${UART}           defaultPauseEmulation=True

*** Test Cases ***
Should Pass Zephyr DMA Loop Transfer Test
    Create Zephyr Machine

    Wait For Line On Uart     I: Device pl330@9300000 initialized

    Wait For Line On Uart     PASS - test_test_dma0_m2m_loop
    Wait For Line On Uart     PASS - test_test_dma0_m2m_loop_repeated_start_stop

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Initialize Linux Driver
    Execute Command                 set bin @${LINUX-BIN}
    Execute Command                 set rootfs @${LINUX-ROOTFS}
    Execute Command                 set dtb @${LINUX-DTB}
    Execute Command                 include @${LINUX-SCRIPT}
    # This is needed for peripheral transfer tests - it occupies unused address
    # channels 2 and 3 are reserved by USART's driver, and shouldn't be used otherwise
    Execute Command                 machine LoadPlatformDescriptionFromString "st_dma_uart: UART.STM32F7_USART @ sysbus 0x4000e000 { frequency: 200000000; IRQ -> gic@55; ReceiveDmaRequest -> dma_pl330@2 }"

    Create Terminal Tester          ${UART}           defaultPauseEmulation=True

    # Make sure the driver initializes
    Wait For Line On Uart           dma-pl330 f8003000.dmac: Loaded driver for PL330 DMAC-341330

    # Wait for Linux to boot up and log into the shell
    Wait For Prompt On Uart         buildroot login:  timeout=25
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}

    Provides                        booted-linux

Should Pass Linux Dmatest
    Requires                     booted-linux

    # It seems like the shell or tty splits long lines, so disable echo
    Write Line To Uart           modprobe dmatest timeout=2000 iterations=5 threads_per_chan=4 channel=dma0chan0 channel=dma0chan1 run=1  waitForEcho=false

    Wait For Line On Uart        dmatest: Started 4 threads using dma0chan0
    Wait For Line On Uart        dmatest: Started 4 threads using dma0chan1

    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true
    Wait For Line On Uart        dmatest: dma\\dchan\\d-copy\\d: summary 5 tests, 0 failures      includeUnfinishedLine=true  treatAsRegex=true

Should Perform Peripheral To Memory Transfer
    Requires                     booted-linux

    # This test uses artificially inserted STM32 USART to trigger transfer using its DMA driver API
    # raw mode forces TTY to print character by character without waiting for new line
    Write Line To Uart           stty -F /dev/ttySTM2 raw
    Wait For Prompt On Uart      ${PROMPT}

    Write Line To Uart           cat /dev/ttySTM2 &
    # USART needs to be woken up and rx channel activated by the driver - give it some time
    # this delay is practically invisible in an interactive flow
    Write Line To Uart           sleep 1
    Wait For Prompt On Uart      ${PROMPT}

    Execute Command              st_dma_uart WriteLine "DMATEST"

    # If DMA works correctly, the same string will be printed on stdout
    Wait For Line On Uart        DMATEST         includeUnfinishedLine=true
