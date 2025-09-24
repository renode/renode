# These tests are based on the Zephyr device drivers, which are in turn based on the QEMU implementation of the Virtio devices
# The driver sometimes exhibits behavior that either does not fit the specification or interprets the specification in a particular way
# Listed here are some idiosyncrasies that the tests and the device implementation will respect in order to facilitate testing of Zephyr drivers

# For the VIRTIO_CONSOLE_DEVICE_ADD, VIRTIO_CONSOLE_DEVICE_REMOVE, VIRTIO_CONSOLE_CONSOLE_PORT messages, QEMU sends 
#   a 0x1 in the value field, despite it being unspecified or specified as unused in the specification.
#   The driver also ignores those fields.

# Console Ports can only be closed by removing the console port using a VIRTIO_CONSOLE_DEVICE_REMOVE message
#   Why the specification of a device calls the control messages for adding and removing ports "*_DEVICE_*" instead of "*_PORT_*" is unclear

# In the current implementation of both driver and device, the VIRTIO_CONSOLE_PORT_OPEN does nothing except print
#   some log messages. The specification also does not provide any insights into what the difference between opening a port and
#   adding a device is. But it may be that DEVICE_ADD/REMOVE is meant to be used for managing the lifecycle of the device
#   while PORT_OPEN/CLOSE is for managing sessions using a device/port combination.

# QEMU only uses one port by default, even with the multiport feature enabled. To test the multiport feature from QEMU
#   CONFIG_QEMU_EXTRA_FLAGS can be used to add additional chardevs and virtconsole devices to the emulation. This can then be 
#   used with socat, picocom etc. to verify the other ports. 
#   A setup like this might be interesting for comparing advanced usage scenarios of the console with these tests.

*** Variables ***
${UART}                     sysbus.virtio_console
${DEVICE_ADDR}              "0x4000a140"
${DEVICE_NAME}              "virtio_console"
${SEED}                     0x42424242
${BIN}                      https://dl.antmicro.com/projects/renode/zephyr-cortex_a53-virtio_mmio_console_test.elf-s_825904-3fa347e7d15d447de6756bf2613dbe959b737a00

*** Keywords ***
Create Machine
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/boards/cortex_a53_console.repl
    Execute Command         sysbus LoadELF @${BIN}
    Execute Command         emulation SetSeed ${SEED}
    Create Terminal Tester  ${UART}

Wait For Init
    Wait For Line On Uart   console device doesn't work as expected:
    Wait For Line On Uart   Start typing characters to see them echoed back

Set Multiport
    [Arguments]             ${value}
    Execute Command         sysbus.virtio_console VirtioConsoleFeatureMultiport ${value}

Remove Port
    [Arguments]             ${port}
    Execute Command         sysbus.virtio_console RemoveDevice ${port}

Add Port
    [Arguments]             ${port}
    Execute Command         sysbus.virtio_console AddDevice ${port}

Make Console Port
    [Arguments]             ${port}
    Execute Command         sysbus.virtio_console MakeConsole ${port}

Change Host Input Port
    [Arguments]             ${port}
    Execute Command         sysbus.virtio_console ChangeUsedPort ${port}

Set Initial Port Number
    [Arguments]             ${numPorts}
    Execute Command         sysbus.virtio_console InitialOpenPortCount ${numPorts}

*** Test Cases ***
Should Receive Text from Driver
    Create Machine
    Set Multiport           false
    Wait For Init

Should Receive Text from Driver Multiport
    Create Machine
    Set Multiport           true
    Wait For Init

Should Echo Back Characters
    Create Machine
    Set Multiport           false
    Wait For Init
    Write Line To Uart      abcd

Should Echo Back Characters Multiport
    Create Machine
    Set Multiport           true
    Wait For Init
    Write Line To Uart      abcd

Create Multiple Devices
    Create Machine
    Set Multiport           true
    Set Initial Port Number    8
    Wait For Init
    Write Line To Uart      abcd

Change Port And Echo Double
    Create Machine
    Set Multiport           true
    Wait For Init
    Add Port                1
    Make Console Port       1
    Write Line To Uart      abcd  waitForEcho=false
    Wait For Line On Uart   aabbccdd
    Remove Port             0
    Change Host Input Port  1
    Write Line To Uart      xyz

Change Port And Echo Bug
    Create Machine
    Set Multiport           true
    Wait For Init
    Add Port                1
    Make Console Port       1
    Remove Port             0
    Change Host Input Port  1
    Write Line To Uart      xyz
