*** Variables ***
${PLATFORM}                         platforms/cpus/cortex-a53-gicv3.repl
${ZEPHYR-BIN}                       https://dl.antmicro.com/projects/renode/cortex-a53--zephyr-pl330-dma_loop_tests.elf-s_70008-bdfc1e055c0dc33dbc846d085bab60e1cdd33352

${LINUX-SCRIPT}                     scripts/single-node/zedboard.resc
${LINUX-BIN}                        https://dl.antmicro.com/projects/renode/zynq--pl330-dmatest-vmlinux-s_14774936-a7c672b2c4fb40a65d87e3454b18813061f18419
${ROOTFS}                           https://dl.antmicro.com/projects/renode/zynq--pl330-dmatest-vmlinux-rootfs.ext2-s_16777216-335b589cf4048764907362ec668c29db88644ffc
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
    Execute Command                 set rootfs @${ROOTFS}
    Execute Command                 include @${LINUX-SCRIPT}

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
