*** Variables ***
${UART}                     sysbus.uart0
${DEVICE_ADDR}              "0x40009140"
${DEVICE_NAME}              "virtio_entropy"
${SEED}                     0x42424242
${BIN}                      https://dl.antmicro.com/projects/renode/zephyr-cortex_a53-virtio_mmio_entropy_test.elf-s_1091728-03a6bb4057b220d8dc3ce3f6498ddf7980b599fd

*** Keywords ***
Create Machine
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/boards/cortex_a53_virtio.repl
    Execute Command         sysbus LoadELF @${BIN}
    Execute Command         emulation SetSeed ${SEED}

*** Test Cases ***
Should Find Device Address and Name
    Create Machine
    Create Terminal Tester  ${UART}
    Start Emulation
    Wait For Line On Uart   random device is 0x4000d140, name is virtio_entropy

Should Deliver Expected Values
    Create Machine
    Create Terminal Tester  ${UART}
    Start Emulation
    Wait For Line On Uart   0x1c
    Wait For Line On Uart   0x80
    Wait For Line On Uart   0x3b
    Wait For Line On Uart   0x9b
    Wait For Line On Uart   0xce
    Wait For Line On Uart   0xaf
    Wait For Line On Uart   0x7a
    Wait For Line On Uart   0xf0
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL

Should Deliver Expected Values Different Seed
    Create Machine
    Create Terminal Tester  ${UART}
    Execute Command         emulation SetSeed 0x42424241
    Start Emulation
    Wait For Line On Uart   0xf1
    Wait For Line On Uart   0xbd
    Wait For Line On Uart   0xfb
    Wait For Line On Uart   0x88
    Wait For Line On Uart   0xeb
    Wait For Line On Uart   0x8d
    Wait For Line On Uart   0x7a
    Wait For Line On Uart   0x25
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL
    
Should Deliver Expected Values Different Seed2
    Create Machine
    Create Terminal Tester  ${UART}
    Execute Command         emulation SetSeed 0x85034985
    Start Emulation
    Wait For Line On Uart   0x4a
    Wait For Line On Uart   0x1e
    Wait For Line On Uart   0x0c
    Wait For Line On Uart   0x34
    Wait For Line On Uart   0x0b
    Wait For Line On Uart   0x0c
    Wait For Line On Uart   0xa9
    Wait For Line On Uart   0x6c
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL
