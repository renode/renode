*** Variables ***
${UART}                         sysbus.uart0
${DRIVE}                        https://dl.antmicro.com/projects/renode/empty-ext4-filesystem.img-s_33554432-1eb65a808612389cc35a69b81178fbad5708a863
${SCRIPT}                       ${CURDIR}/../../scripts/single-node/hifive_unleashed.resc
${INPUT}                        Quick Brown Fox Jumps Over the Lazy Dog
${PROMPT}                       #

*** Keywords ***
Create Machine
    Execute Command             \$fdt?=@https://dl.antmicro.com/projects/renode/virtio-hifive_unleashed.dtb-s_10640-08834542504afb748827fdca52515f156e971d5f
    Execute Script              ${SCRIPT}
    Execute Command             machine LoadPlatformDescriptionFromString 'virtio: Storage.VirtIOBlockDevice @ sysbus 0x100d0000 { IRQ -> plic@50 }'

Prepare Drive
    ${TEMP_DRIVE}=              Download File  ${DRIVE}
    Set Suite Variable          ${DRIVE_PATH}    ${TEMP_DRIVE}

Setup Machine
    Wait For Prompt On Uart     buildroot login:
    Write Line To Uart          root
    Wait For Prompt On Uart     Password:
    Write Line To Uart          root             waitForEcho=false
    Wait For Prompt On Uart     ${PROMPT}
    
    Execute Command             virtio LoadImage @${DRIVE_PATH} true
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          dmesg -n 1
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mkdir /mnt/drive
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mount /dev/vda /mnt/drive
    Wait For Prompt On Uart     ${PROMPT}

*** Test Cases ***
Should Boot
    Prepare Drive
    Create Machine
    Create Terminal Tester      ${UART}
    Start Emulation
    
    Setup Machine
    Write Line To Uart          echo ${INPUT} > /mnt/drive/file
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          cat /mnt/drive/file
    Wait For Line On Uart       ${INPUT}
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          umount /dev/vda
    Wait For Prompt On Uart     ${PROMPT}
    # We encountered data corruption when closing the emulation right after `umount`.
    # Although `umount` should wait for all write operations on the device to finish, we noticed writes even after the prompt in bash is printed.
    # Surprisingly even using `sync; sync` doesn't help here.
    # As a workaround let's include sleep, but this should be fixed later.
    Sleep                       5s

Should Be Persistent
    Create Machine
    Create Terminal Tester      ${UART}
    Start Emulation
    
    Setup Machine
    Write Line To Uart          cat /mnt/drive/file
    Wait For Line On Uart       ${INPUT}
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          umount /dev/vda
    Wait For Prompt On Uart     ${PROMPT}
