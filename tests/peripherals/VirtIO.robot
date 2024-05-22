*** Settings ***
Suite Setup                     Custom Suite Setup
Suite Teardown                  Custom Suite Teardown
Library                         OperatingSystem

*** Variables ***
${UART}                         sysbus.uart0
${DRIVE}                        https://dl.antmicro.com/projects/renode/empty-ext4-filesystem.img-s_33554432-1eb65a808612389cc35a69b81178fbad5708a863
${FS}                           https://dl.antmicro.com/projects/renode/virtio-filesystem-passthrough_hp_uds-s_7318728-f7b60ce9b60c82cede19e798e81971663e1c0ad2
${SCRIPT_BLK}                   ${CURDIR}/../../scripts/single-node/hifive_unleashed.resc
${SCRIPT_FS}                    ${CURDIR}/../../tests/peripherals/virtio-vexriscv.resc
${INPUT}                        Quick Brown Fox Jumps Over the Lazy Dog
${PROMPT}                       #
${SOCK_FILE}                    libfuse-passthrough-hp.sock
${SOCK_PATH}                    ${TEMPDIR}${/}${SOCK_FILE}
${SHARED_FILE}                  testfile
${SHARED_DIR}                   shareddir
${VIRTIOFS_TAG}                 "MySharedDir"
${SYSTEM}=                      Evaluate         platform.system()    modules=platform

*** Keywords ***
Custom Suite Setup
    Setup

    ${TEMP_DRIVE}=              Download File    ${DRIVE}
    ${DIR}  ${FILE_NAME}=       Split Path       ${TEMP_DRIVE}
    Copy File                   ${TEMP_DRIVE}    ${TEMPDIR}
    Set Suite Variable          ${DRIVE_PATH}    ${TEMPDIR}${/}${FILE_NAME}
    ${TEMP_FS}=                 Download File    ${FS}
    ${DIR}  ${FILE_NAME}=       Split Path       ${TEMP_FS}
    Copy File                   ${TEMP_FS}       ${TEMPDIR}
    Set Suite Variable          ${FS_PATH}       ${TEMPDIR}${/}${FILE_NAME}
    Run Process                 chmod    +x      ${FS_PATH}

Custom Suite Teardown
    Remove File                 ${DRIVE_PATH}
    Remove File                 ${FS_PATH}
    Teardown

Create Machine VirtIOBlock
    Execute Command             $fdt=@https://dl.antmicro.com/projects/renode/virtio-hifive_unleashed.dtb-s_10640-08834542504afb748827fdca52515f156e971d5f
    Execute Script              ${SCRIPT_BLK}
    Execute Command             machine LoadPlatformDescriptionFromString 'virtioblk: Storage.VirtIOBlockDevice @ sysbus 0x100d0000 { IRQ -> plic@50 }'

Create Machine VirtIOFS
    Execute Command             $platform=@tests/peripherals/virtio-platform.repl
    Execute Command             $img=@https://dl.antmicro.com/projects/renode/virtio-filesystem-image-s_8448188-414604e8f64c41ebdbffe0f9ae7525c20bb1b124
    Execute Command             $dtb=@https://dl.antmicro.com/projects/renode/virtio-filesystem-rv32.dtb-s_1806-b2ad3ecaf517c6a6781d1cbb48eff6fca7972094
    Execute Command             $osbi=@https://dl.antmicro.com/projects/renode/litex_vexriscv_smp--opensbi.bin-s_45360-dcfe5f7b149bd1e0232609d87fb698f95f5e33c4
    Execute Command             $rootfs=@https://dl.antmicro.com/projects/renode/virtio-filesystem-rootfs.cpio-s_39962112-95a3591d189699f21b988b036a9843c882d8e42f
    Execute Command             $sock_path=@${SOCK_PATH}
    Execute Command             $virtiofs_tag=${VIRTIOFS_TAG}
    Execute Script              ${SCRIPT_FS}

Setup Machine VirtIOBlock
    Wait For Prompt On Uart     buildroot login:
    Write Line To Uart          root
    Wait For Prompt On Uart     Password:
    Write Line To Uart          root             waitForEcho=false
    Wait For Prompt On Uart     ${PROMPT}
    Execute Command             virtioblk LoadImage @${DRIVE_PATH} true
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          dmesg -n 1
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mkdir /mnt/drive
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mount /dev/vda /mnt/drive
    Wait For Prompt On Uart     ${PROMPT}

Setup Machine VirtIOFS
    Wait For Prompt On Uart     buildroot login: 
    Write Line To Uart          root
    Wait For Line On Uart       root login on 'console'
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mkdir ${SHARED_DIR}
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          mount -t virtiofs ${VIRTIOFS_TAG} ${SHARED_DIR}
    Wait For Prompt On Uart     ${PROMPT}

Setup Shared Directory
    Create Directory            ${SHARED_DIR}
    Create File                 ${SHARED_DIR}/${SHARED_FILE}    ${INPUT}

*** Test Cases ***
Read Shared Directory
    [Tags]                      skip_windows    skip_osx
    # Unix domain sockets

    Setup Shared Directory
    ${FS_PROCESS}=              Start Process    ${FS_PATH}    ${SHARED_DIR}    --socket    ${SOCK_PATH}

    Create Machine VirtIOFS
    Create Terminal Tester      ${UART}
    Start Emulation
    
    Setup Machine VirtIOFS
    Write Line To Uart          ls -al ${SHARED_DIR}
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          cat ${SHARED_DIR}/${SHARED_FILE}
    Wait For Prompt On Uart     ${INPUT}
    Sleep                       5s
    Terminate Process           ${FS_PROCESS}    kill=true
    Run Process                 rm    ${SOCK_PATH}

Should Boot
    Create Machine VirtIOBlock
    Create Terminal Tester      ${UART}
    Start Emulation
    
    Setup Machine VirtIOBlock
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
    Create Machine VirtIOBlock
    Create Terminal Tester      ${UART}
    Start Emulation
    
    Setup Machine VirtIOBlock 
    Write Line To Uart          cat /mnt/drive/file
    Wait For Line On Uart       ${INPUT}
    Wait For Prompt On Uart     ${PROMPT}
    Write Line To Uart          umount /dev/vda
    Wait For Prompt On Uart     ${PROMPT}
